#=
Code Copied from https://github.com/tkoolen/TypeSortedCollections.jl and modified given that
the original repo is no longer maintained. The original broadcasting code was removed given this
dicussion https://discourse.julialang.org/t/broadcasting-in-0-7/12346/1
=#

const TupleOfVectors = Tuple{Vararg{Vector{T} where T}}

struct TypeSortedCollection{D <: TupleOfVectors, N}
    data::D
    indices::NTuple{N, Vector{Int}}

    function TypeSortedCollection{D, N}(
        data::D,
        indices::NTuple{N, Vector{Int}},
    ) where {D <: TupleOfVectors, N}
        fieldcount(D) == N || error()
        l = mapreduce(length, +, data; init = 0)
        l == mapreduce(length, +, indices; init = 0) || error()
        if N > 0
            allindices = Base.Iterators.flatten(indices)
            allunique(allindices) || error()
            isempty(allindices) || extrema(allindices) == (1, l) || error()
        end
        new{D, N}(data, indices)
    end

    function TypeSortedCollection{D, N}(
        indices::NTuple{N, Vector{Int}},
    ) where {D <: TupleOfVectors, N}
        lengths = map(length, indices)
        data = ntuple(i -> D.parameters[i](undef, lengths[i]), N)
        TypeSortedCollection{D, N}(data, indices)
    end

    function TypeSortedCollection{D, N}() where {D <: TupleOfVectors, N}
        indices = ntuple(_ -> Int[], N)
        TypeSortedCollection{D, N}(indices)
    end

    TypeSortedCollection{D}() where {D <: TupleOfVectors} =
        TypeSortedCollection{D, length(D.parameters)}()
    TypeSortedCollection{D, N}(A) where {D <: TupleOfVectors, N} =
        append!(TypeSortedCollection{D, N}(), A)
    TypeSortedCollection{D}(A) where {D <: TupleOfVectors} =
        append!(TypeSortedCollection{D}(), A)
end

function TypeSortedCollection(
    data::D,
    indices::NTuple{N, Vector{Int}},
) where {D <: TupleOfVectors, N}
    TypeSortedCollection{D, N}(data, indices)
end

function TypeSortedCollection(A, preserve_order::Bool = false)
    if preserve_order
        data = Vector[]
        indices = Vector{Vector{Int}}()
        for (i, x) in enumerate(A)
            T = typeof(x)
            if isempty(data) || T != eltype(last(data))
                push!(data, T[])
                push!(indices, Int[])
            end
            push!(last(data), x)
            push!(last(indices), i)
        end
        TypeSortedCollection(tuple(data...), tuple(indices...))
    else
        types = unique(typeof.(A))
        D = Tuple{[Vector{T} for T in types]...}
        TypeSortedCollection{D}(A)
    end
end

function TypeSortedCollection(A, indices::NTuple{N, Vector{Int}} where {N})
    @assert length(A) == mapreduce(length, +, indices; init = 0)
    data = []
    for indicesvec in indices
        T = length(indicesvec) > 0 ? typeof(A[indicesvec[1]]) : Nothing
        Tdata = Vector{T}()
        sizehint!(Tdata, length(indicesvec))
        push!(data, Tdata)
        for i in indicesvec
            A[i]::T
            push!(Tdata, A[i])
        end
    end
    TypeSortedCollection(tuple(data...), indices)
end

@inline Base.eltype(A::TypeSortedCollection) = Union{map(eltype, A.data)...}

# lots of lisp-y type recursion in definitions below

# eltypes just looks at the types of the vectors stored in the TSC.
eltypes(::Type{TypeSortedCollection{D, N}}) where {D, N} = eltypes(D)

function eltypes(::Type{T}) where {T <: TupleOfVectors}
    Base.tuple_type_cons(eltype(Base.tuple_type_head(T)), eltypes(Base.tuple_type_tail(T)))
end
eltypes(::Type{Tuple{}}) = Tuple{}

function vectortypes(::Type{T}) where {T <: Tuple} # Tuple, not TupleOfVectors. needed why?
    Base.tuple_type_cons(
        Vector{Base.tuple_type_head(T)},
        vectortypes(Base.tuple_type_tail(T)),
    )
end
vectortypes(::Type{Tuple{}}) = Tuple{}

@generated function Base.push!(dest::TypeSortedCollection{D}, x::X) where {D, X}
    i = 0
    for j in 1:length(D.parameters)
        Vector{X} == D.parameters[j] && (i = j; break)
    end
    i == 0 && return :(throw(
        ArgumentError("Destination cannot store arguments of type $(typeof(x))."),
    ))
    quote
        Base.@_inline_meta
        index = length(dest) + 1
        push!(dest.data[$i], x)
        push!(dest.indices[$i], index)
        return dest
    end
end

function Base.append!(dest::TypeSortedCollection, A)
    # TODO: consider resizing first
    for x in A
        push!(dest, x)
    end
    return dest
end

num_types(::Type{<:TypeSortedCollection{<:Any, N}}) where {N} = N
num_types(x::TypeSortedCollection) = num_types(typeof(x))

const TSCOrAbstractVector{N} = Union{<:TypeSortedCollection{<:Any, N}, AbstractVector}

Base.isempty(x::TypeSortedCollection) = all(isempty, x.data)
Base.empty!(x::TypeSortedCollection) = foreach(empty!, x.data)
@inline Base.length(x::TypeSortedCollection) = mapreduce(length, +, x.data; init = 0)
indices(x::TypeSortedCollection) = x.indices

# Trick from StaticArrays: [find the first TypeSortedCollection in a vararg list]
@inline first_tsc(a1::TypeSortedCollection, as...) = a1
@inline first_tsc(a1, as...) = first_tsc(as...)

@inline first_tsc_type(a1::Type{<:TypeSortedCollection}, as::Type...) = a1
@inline first_tsc_type(a1::Type, as::Type...) = first_tsc_type(as...)

# inspired by Base.ith_all. 
# example: _getindex_all(Val(i), j, tsc1, tsc2, tsc3) returns (tsc1[i][j], tsc2[i][j], tsc3[i][j])
@inline _getindex_all(::Val, j, vecindex) = ()
Base.@propagate_inbounds @inline _getindex_all(
    vali::Val{i},
    j,
    vecindex,
    a1,
    as...,
) where {i} = (_getindex(vali, j, vecindex, a1), _getindex_all(vali, j, vecindex, as...)...)
@inline _getindex(::Val, j, vecindex, a) = a # for anything that's not an AbstractVector or TypeSortedCollection, don't index (for use in broadcast!)
# concretely: in an expression like tsc .+ 5, 5 should be broadcasted, not indexed.
@inline _getindex(::Val, j, vecindex, a::AbstractVector) = a[vecindex]
@inline _getindex(::Val, j, vecindex, a::Ref) = a[]
@inline _getindex(::Val{i}, j, vecindex, a::TypeSortedCollection) where {i} = a.data[i][j]
@inline _setindex!(::Val, j, vecindex, a::AbstractVector, val) = a[vecindex] = val
@inline _setindex!(::Val{i}, j, vecindex, a::TypeSortedCollection, val) where {i} =
    a.data[i][j] = val

# defined so that we can check if it's okay to do a .+ b on two TSCs a, b.
@inline lengths_match(a1) = true
@inline lengths_match(a1::TSCOrAbstractVector, a2::TSCOrAbstractVector, as...) =
    length(a1) == length(a2) && lengths_match(a2, as...)
@inline lengths_match(a1::TSCOrAbstractVector, a2, as...) = lengths_match(a1, as...) # case: a2 is not indexable: skip it
@noinline lengths_match_fail() =
    throw(DimensionMismatch("Lengths of input collections do not match."))

@inline indices_match(::Val, indices::Vector{Int}, ::Any) = true
@inline function indices_match(
    ::Val{i},
    indices::Vector{Int},
    tsc::TypeSortedCollection,
) where {i}
    tsc_indices = tsc.indices[i]
    length(indices) == length(tsc_indices) || return false
    @inbounds for j in eachindex(indices)
        indices[j] == tsc_indices[j] || return false
    end
    true
end
@inline indices_match(vali::Val, indices::Vector{Int}, a1, as...) =
    indices_match(vali, indices, a1) && indices_match(vali, indices, as...)
@noinline indices_match_fail() =
    throw(ArgumentError("Indices of TypeSortedCollections do not match."))

@generated function Base.map!(
    f::F,
    dest::TSCOrAbstractVector{N},
    src1::TypeSortedCollection{<:Any, N},
    srcs::TSCOrAbstractVector{N}...,
) where {F, N}
    expr = Expr(:block)
    for i in 1:N
        vali = Val(i)
        push!(
            expr.args,
            quote
                let inds = leading_tsc.indices[$i]
                    @boundscheck indices_match($vali, inds, dest, src1, srcs...) ||
                                 indices_match_fail()
                    @inbounds for j in LinearIndices(inds)
                        vecindex = inds[j]
                        _setindex!(
                            $vali,
                            j,
                            vecindex,
                            dest,
                            f(_getindex_all($vali, j, vecindex, src1, srcs...)...),
                        )
                    end
                end
            end,
        )
    end
    quote
        Base.@_inline_meta
        leading_tsc = first_tsc(dest, src1, srcs...)
        @boundscheck lengths_match(dest, src1, srcs...) || lengths_match_fail()
        $expr
        dest
    end
end

@generated function Base.foreach(
    f::F,
    A1::TypeSortedCollection{<:Any, N},
    As::TSCOrAbstractVector{N}...,
) where {F, N}
    expr = Expr(:block)
    for i in 1:N
        vali = Val(i)
        push!(
            expr.args,
            quote
                let inds = leading_tsc.indices[$i]
                    @boundscheck indices_match($vali, inds, A1, As...) ||
                                 indices_match_fail()
                    @inbounds for j in LinearIndices(inds)
                        vecindex = inds[j]
                        f(_getindex_all($vali, j, vecindex, A1, As...)...)
                    end
                end
            end,
        )
    end
    quote
        Base.@_inline_meta
        leading_tsc = first_tsc(A1, As...)
        @boundscheck lengths_match(A1, As...) || lengths_match_fail()
        $expr
        nothing
    end
end

@generated function Base.mapreduce(
    f::F,
    op::O,
    tsc::TypeSortedCollection{<:Any, N};
    init,
) where {F, O, N}
    quote
        Base.@_inline_meta
        ret = init
        $([:(ret = mapreduce(f, op, tsc.data[$i]; init = ret)) for i in 1:N]...)
        return ret
    end
end

@generated function Base.any(f::F, tsc::TypeSortedCollection{<:Any, N}) where {F, N}
    expr = Expr(:block)
    for i in 1:N
        push!(expr.args, quote
            v = any(f, tsc.data[$i])
            if ismissing(v)
                anymissing = true
            elseif v
                return true
            end
        end)
    end
    quote
        Base.@_inline_meta
        anymissing = false
        $expr
        anymissing ? missing : false
    end
end

@generated function Base.all(f::F, tsc::TypeSortedCollection{<:Any, N}) where {F, N}
    expr = Expr(:block)
    for i in 1:N
        push!(expr.args, quote
            v = all(f, tsc.data[$i])
            if ismissing(v)
                anymissing = true
            elseif !v
                return false
            end
        end)
    end
    quote
        Base.@_inline_meta
        anymissing = false
        $expr
        anymissing ? missing : true
    end
end

# TODO seems like this should really be written using axes.
# TODO are structs Val-friendly? I don't see a simple way to make do with just a single Int state.
struct TSCIterState
    type_index::Int   # Which type group (1 to N)
    elem_index::Int   # Position within that type group
end

# TODO do I need @inline or @generated here on left side?
Base.iterate(tsc::TypeSortedCollection{D, N}) where {D, N} = _iterate_tsc(tsc, Val(1), 1)
Base.iterate(
    tsc::TypeSortedCollection{D, N},
    state::TSCIterState,
) where {D, N} = _iterate_tsc(tsc, Val(state.type_index), state.elem_index)

# TODO what about TSCOrAbstractVector?
# TODO bounds errors and @inbounds?
# PERF: for "large" N (how large?), the recursive tail might be unwieldy, very long.
# if we could assume the collections are all non-empty, this would be simpler.
@generated function _iterate_tsc(
    tsc::TypeSortedCollection{D, N},
    ::Val{group},
    elem_idx::Int,
) where {D, N, group}
    if group > N
        return :(nothing)
    end

    quote
        vec = tsc.data[$group]

        if elem_idx <= length(vec)
            element = vec[elem_idx]
            return (element, TSCIterState($group, elem_idx + 1))
        end

        # Move to next group (compile-time recursion)
        return _iterate_tsc(tsc, Val($(group + 1)), 1)
    end
end

# slow: only intended for testing purposes.
function Base.collect(tsc::TypeSortedCollection)
    if isempty(tsc)
        return Vector{eltype(tsc)}()
    end
    nonempty_data_array = 1
    while isempty(tsc.data[nonempty_data_array])
        nonempty_data_array += 1
    end
    sample_element = first(tsc.data[nonempty_data_array])
    result = Vector{eltype(tsc)}(fill(sample_element, length(tsc)))
    for (indices, items) in zip(tsc.indices, tsc.data)
        for (i, item) in zip(indices, items)
            result[i] = item
        end
    end
    return result
end
