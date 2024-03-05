import InteractiveUtils

g_cached_subtypes = Dict{DataType, Vector{DataType}}()

"""
Returns an array of all concrete subtypes of T.
Note that this does not find parameterized types.
"""
function get_all_concrete_subtypes(::Type{T}) where {T}
    if haskey(g_cached_subtypes, T)
        return g_cached_subtypes[T]
    end

    sub_types = Vector{DataType}()
    _get_all_concrete_subtypes(T, sub_types)
    g_cached_subtypes[T] = sub_types
    return sub_types
end

"""
Recursively builds a vector of subtypes.
"""
function _get_all_concrete_subtypes(::Type{T}, sub_types::Vector{DataType}) where {T}
    for sub_type in InteractiveUtils.subtypes(T)
        if isconcretetype(sub_type)
            push!(sub_types, sub_type)
        elseif isabstracttype(sub_type)
            _get_all_concrete_subtypes(sub_type, sub_types)
        end
    end

    return nothing
end

"""
Returns an array of concrete types that are direct subtypes of T.
"""
function get_concrete_subtypes(::Type{T}) where {T}
    return [x for x in InteractiveUtils.subtypes(T) if isconcretetype(x)]
end

"""
Returns an array of abstract types that are direct subtypes of T.
"""
function get_abstract_subtypes(::Type{T}) where {T}
    return [x for x in InteractiveUtils.subtypes(T) if isabstracttype(x)]
end

"""
Returns an array of all super types of T.
"""
function supertypes(::Type{T}, types = []) where {T}
    super = supertype(T)
    push!(types, super)
    if super == Any
        return types
    end

    return supertypes(super, types)
end

"""
Converts a DataType to a Symbol, stripping off the module name(s).
"""
function type_to_symbol(data_type::DataType)
    return Symbol(strip_module_name(string(data_type)))
end

"""
Strips the module name off of a type.
"""
function strip_module_name(name::String)
    index = findfirst(".", name)
    # Account for the period being part of a parametric type.
    parametric_index = findfirst("{", name)

    if isnothing(index) ||
       (!isnothing(parametric_index) && index.start > parametric_index.start)
        basename = name
    else
        basename = name[(index.start + 1):end]
    end

    return basename
end

function strip_module_name(::Type{T}) where {T}
    return strip_module_name(string(T))
end

function strip_parametric_type(name::AbstractString)
    index = findfirst("{", name)
    if !isnothing(index)
        # Ignore the parametric type.
        name = name[1:(index.start - 1)]
    end

    return name
end

"""
Return true if all publicly exported names in mod are defined.
"""
function validate_exported_names(mod::Module)
    is_valid = true
    for name in names(mod)
        if !isdefined(mod, name)
            is_valid = false
            @error "module $mod exports $name but does not define it"
        end
    end

    return is_valid
end

"""
Recursively compares struct values. Prints all mismatched values to stdout.

# Arguments

  - `x::T`: First value
  - `y::T`: Second value
  - `compare_uuids::Bool = false`: Compare any UUID in the object or composed objects.
"""
function compare_values(x::T, y::T; compare_uuids = false) where {T}
    match = true
    fields = fieldnames(T)
    if isempty(fields)
        match = x == y
    else
        for field_name in fields
            if (T <: TimeSeriesContainer || T <: SupplementalAttributes) &&
               field_name == :time_series_storage
                # This gets validated at SystemData. Don't repeat for each component.
                continue
            end
            val1 = getproperty(x, field_name)
            val2 = getproperty(y, field_name)
            if !isempty(fieldnames(typeof(val1)))
                if !compare_values(val1, val2; compare_uuids = compare_uuids)
                    @error "values do not match" T field_name val1 val2
                    match = false
                end
            elseif val1 isa AbstractArray
                if !compare_values(val1, val2; compare_uuids = compare_uuids)
                    @error "values do not match" T field_name val1 val2
                    match = false
                end
            else
                if val1 != val2
                    @error "values do not match" T field_name val1 val2
                    match = false
                end
            end
        end
    end

    return match
end

function compare_values(x::Vector{T}, y::Vector{T}; compare_uuids = false) where {T}
    if length(x) != length(y)
        @error "lengths do not match" T length(x) length(y)
        return false
    end

    match = true
    for i in range(1; length = length(x))
        if !compare_values(x[i], y[i]; compare_uuids = compare_uuids)
            @error "values do not match" typeof(x[i]) i x[i] y[i]
            match = false
        end
    end

    return match
end

function compare_values(x::Dict, y::Dict; compare_uuids = false)
    keys_x = Set(keys(x))
    keys_y = Set(keys(y))
    if keys_x != keys_y
        @error "keys don't match" keys_x keys_y
        return false
    end

    match = true
    for key in keys_x
        if !compare_values(x[key], y[key]; compare_uuids = compare_uuids)
            @error "values do not match" typeof(x[key]) key x[key] y[key]
            match = false
        end
    end

    return match
end

compare_values(x::Float64, y::Int; compare_uuids = false) = x == Float64(y)
compare_values(::Type{T}, ::Type{T}; compare_uuids = false) where {T} = true
compare_values(::Type{T}, ::Type{U}; compare_uuids = false) where {T, U} = false

# Copied from https://discourse.julialang.org/t/encapsulating-enum-access-via-dot-syntax/11785/10
"""
Macro to wrap Enum in a module to keep the top level scope clean.

# Examples

```Julia
julia> @scoped_enum Fruit APPLE = 1 ORANGE = 2

julia> value = Fruit.APPLE
Fruit.APPLE = 1

julia> value = Fruit(1)
Fruit.APPLE = 1

julia> @scoped_enum(Fruit,
    APPLE = 1,  # comment
    ORANGE = 2,  # comment
)
```
"""
macro scoped_enum(T, args...)
    blk = esc(
        :(
            module $(Symbol("$(T)Module"))
            using JSON3
            export $T
            struct $T
                value::Int64
            end
            const NAME2VALUE =
                $(Dict(String(x.args[1]) => Int64(x.args[2]) for x in args))
            $T(str::String) = $T(NAME2VALUE[str])
            const VALUE2NAME =
                $(Dict(Int64(x.args[2]) => String(x.args[1]) for x in args))
            Base.string(e::$T) = VALUE2NAME[e.value]
            Base.getproperty(::Type{$T}, sym::Symbol) =
                haskey(NAME2VALUE, String(sym)) ? $T(String(sym)) : getproperty($T, sym)
            Base.show(io::IO, e::$T) =
                print(io, string($T, ".", string(e), " = ", e.value))
            Base.propertynames(::Type{$T}) = $([x.args[1] for x in args])
            JSON3.StructType(::Type{$T}) = JSON3.StructTypes.StringType()

            Base.convert(::Type{$T}, val::Integer) = $T(val)
            Base.isless(val::$T, other::$T) = isless(val.value, other.value)
            Base.instances(::Type{$T}) = tuple($T.($(x.args[2] for x in args))...)
            end
        ),
    )
    top = Expr(:toplevel, blk)
    push!(top.args, :(using .$(Symbol("$(T)Module"))))
    return top
end

function compose_function_delegation_string(
    sender_type::String,
    sender_symbol::String,
    argid::Vector{Int},
    method::Method,
)
    s = "p" .* string.(1:(method.nargs - 1))
    s .*= "::" .* string.(fieldtype.(Ref(method.sig), 2:(method.nargs)))
    s[argid] .= "p" .* string.(argid) .* "::$sender_type"

    m = string(method.module.eval(:(parentmodule($(method.name))))) * "."
    l = "$m:(" * string(method.name) * ")(" * join(s, ", ")

    m = string(method.module) * "."
    l *= ") = $m:(" * string(method.name) * ")("
    s = "p" .* string.(1:(method.nargs - 1))

    s[argid] .= "getproperty(" .* s[argid] .* ", :$sender_symbol)"
    l *= join(s, ", ") * ")"
    l = join(split(l, "#"))
    return l
end

function forward(sender::Tuple{Type, Symbol}, ::Type, method::Method)
    # Assert that function is always just one argument
    @assert method.nargs < 4 "`forward` only works for one and two argument functions"
    # Assert that function name always starts with `get_*`
    "`forward` only works for accessor methods that are defined as `get_*` or `set_*`"
    @assert startswith(string(method.name), r"set_|get_")
    sender_type = "$(parentmodule(sender[1])).$(strip_module_name(sender[1]))"
    sender_symbol = string(sender[2])
    code_array = Vector{String}()
    # Search for receiver type in method arguments
    argtype = fieldtype(method.sig, 2)
    (sender[1] == argtype) && (return code_array)
    if string(method.name)[1] == '@'
        @warn "Forwarding macros is not yet supported."
        display(method)
        println()
        return code_array
    end

    # first argument only
    push!(
        code_array,
        compose_function_delegation_string(sender_type, sender_symbol, [1], method),
    )

    tmp = split(string(method.module), ".")[1]
    code =
        "@eval " .* tmp .* " " .* code_array .* " # " .* string(method.file) .* ":" .*
        string(method.line)
    if (tmp != "Base") && (tmp != "Main")
        pushfirst!(code, "using $tmp")
    end
    code = unique(code)
    return code
end

function forward(sender::Tuple{Type, Symbol}, receiver::Type, exclusions::Vector{Symbol})
    @assert isconcretetype(sender[1])
    @assert isconcretetype(receiver)
    code = Vector{String}()
    active_methods = getfield.(InteractiveUtils.methodswith(sender[1]), :name)
    for m in InteractiveUtils.methodswith(receiver)
        m.name ∈ exclusions && continue
        m.name ∈ active_methods && continue
        if startswith(string(m.name), "get_") && m.nargs == 2
            # forwarding works for functions with 1 argument and starts with `get_`
            append!(code, forward(sender, receiver, m))
        elseif startswith(string(m.name), "set_") && m.nargs == 3
            # forwarding works for functions with 2 argument and starts with `set_`
            append!(code, forward(sender, receiver, m))
        end
    end
    return code
end

macro forward(sender, receiver, exclusions = Symbol[])
    out = quote
        list = InfrastructureSystems.forward($sender, $receiver, $exclusions)
        for line in list
            eval(Meta.parse("$line"))
        end
    end
    return esc(out)
end

"""
Return the resolution from a TimeArray.
"""
function get_resolution(ts::TimeSeries.TimeArray)
    tstamps = TimeSeries.timestamp(ts)
    timediffs = unique([tstamps[ix] - tstamps[ix - 1] for ix in 2:length(tstamps)])

    res = []

    for timediff in timediffs
        if mod(timediff, Dates.Millisecond(Dates.Day(1))) == Dates.Millisecond(0)
            push!(res, Dates.Day(timediff / Dates.Millisecond(Dates.Day(1))))
        elseif mod(timediff, Dates.Millisecond(Dates.Hour(1))) == Dates.Millisecond(0)
            push!(res, Dates.Hour(timediff / Dates.Millisecond(Dates.Hour(1))))
        elseif mod(timediff, Dates.Millisecond(Dates.Minute(1))) == Dates.Millisecond(0)
            push!(res, Dates.Minute(timediff / Dates.Millisecond(Dates.Minute(1))))
        elseif mod(timediff, Dates.Millisecond(Dates.Second(1))) == Dates.Millisecond(0)
            push!(res, Dates.Second(timediff / Dates.Millisecond(Dates.Second(1))))
        else
            throw(DataFormatError("cannot understand the resolution of the time series"))
        end
    end

    if length(res) > 1
        throw(
            DataFormatError(
                "time series has non-uniform resolution: this is currently not supported",
            ),
        )
    end

    return res[1]
end

function get_initial_timestamp(data::TimeSeries.TimeArray)
    return TimeSeries.timestamp(data)[1]
end

function get_module(module_name)
    # root_module cannot find InfrastructureSystems if it hasn't been installed by the
    # user (but has been installed as a dependency to another package).
    return if module_name == "InfrastructureSystems"
        InfrastructureSystems
    else
        Base.root_module(Base.__toplevel__, Symbol(module_name))
    end
end

get_type_from_strings(module_name, type) = getproperty(get_module(module_name), Symbol(type))

# This function is used instead of cp given
# https://github.com/JuliaLang/julia/issues/30723
function copy_file(src::AbstractString, dst::AbstractString)
    src_path = normpath(src)
    dst_path = normpath(dst)
    if Sys.iswindows()
        run(`cmd /c copy /Y $(src_path) $(dst_path)`)
    else
        run(`cp -f $(src_path) $(dst_path)`)
    end
    return
end

function get_initial_times(
    initial_timestamp::Dates.DateTime,
    count::Int,
    interval::Dates.Period,
)
    if count == 0
        return []
    elseif interval == Dates.Second(0)
        return [initial_timestamp]
    end

    return range(initial_timestamp; length = count, step = interval)
end

function get_total_period(
    initial_timestamp::Dates.DateTime,
    count::Int,
    interval::Dates.Period,
    horizon::Int,
    resolution::Dates.Period,
)
    last_it = initial_timestamp + interval * count
    last_timestamp = last_it + resolution * (horizon - 1)
    return last_timestamp - initial_timestamp
end

function transform_array_for_hdf(data::SortedDict{Dates.DateTime, Vector{CONSTANT}})
    return hcat(values(data)...)
end

function transform_array_for_hdf(data::Vector{<:Real})
    return data
end

transform_array_for_hdf(data::SortedDict{Dates.DateTime, Vector{LinearFunctionData}}) =
    transform_array_for_hdf(
        SortedDict{Dates.DateTime, Vector{CONSTANT}}(
            k => get_proportional_term.(v) for (k, v) in data
        ),
    )

transform_array_for_hdf(data::Vector{LinearFunctionData}) =
    transform_array_for_hdf(get_proportional_term.(data))

transform_array_for_hdf(data::Vector{PolynomialFunctionData}) =
    throw(ArgumentError("Not yet implemented for PolynomialFunctionData"))

transform_array_for_hdf(data::SortedDict{Dates.DateTime, Vector{PolynomialFunctionData}}) =
    throw(ArgumentError("Not yet implemented for PolynomialFunctionData"))

function transform_array_for_hdf(
    data::SortedDict{Dates.DateTime, Vector{QuadraticFunctionData}},
)
    all(get_constant_term.(vcat(values(data)...)) .== 0) ||
        throw(
            ArgumentError(
                "Not yet implemented for nonzero constant term ($(get_constant_term.(vcat(values(data)...))))",
            ),
        )
    data = SortedDict(
        k =>
            [(get_quadratic_term(q), (get_proportional_term(q))) for q in v] for
        (k, v) in data
    )
    lin_cost = hcat(values(data)...)
    rows, cols = size(lin_cost)
    @assert_op length(first(lin_cost)) == 2
    t_lin_cost = Array{Float64}(undef, rows, cols, 2)
    for r in 1:rows, c in 1:cols
        tuple = lin_cost[r, c]
        for (i, value) in enumerate(tuple)
            t_lin_cost[r, c, i] = value
        end
    end
    return t_lin_cost
end

function transform_array_for_hdf(data::Vector{QuadraticFunctionData})
    all(get_constant_term.(data) .== 0) ||
        throw(ArgumentError("Not yet implemented for nonzero constant term"))
    data = [(get_quadratic_term(q), (get_proportional_term(q))) for q in data]
    rows = length(data)
    @assert_op length(first(data)) == 2
    t_lin_cost = Array{Float64}(undef, rows, 1, 2)
    for r in 1:rows
        tuple = data[r]
        for (i, value) in enumerate(tuple)
            t_lin_cost[r, 1, i] = value
        end
    end
    return t_lin_cost
end

function transform_array_for_hdf(
    data::SortedDict{Dates.DateTime, Vector{PiecewiseLinearPointData}},
)
    quad_cost = hcat([get_points.(v) for v in values(data)]...)
    rows, cols = size(quad_cost)
    tuple_length = length(first(quad_cost))
    @assert_op length(first(first(quad_cost))) == 2
    t_quad_cost = Array{Float64}(undef, rows, cols, 2, tuple_length)
    for r in 1:rows, c in 1:cols
        tuple_array = quad_cost[r, c]
        for (j, tuple) in enumerate(tuple_array)
            for (i, value) in enumerate(tuple)
                t_quad_cost[r, c, i, j] = value
            end
        end
    end
    return t_quad_cost
end

# TODO: old code here does not properly handle data with different numbers of points
# TODO: remove duplication
function transform_array_for_hdf(data::Vector{PiecewiseLinearPointData})
    data = get_points.(data)
    rows = length(data)
    tuple_length = length(first(data))
    @assert_op length(first(first(data))) == 2
    t_quad_cost = Array{Float64}(undef, rows, 1, 2, tuple_length)
    for r in 1:rows
        tuple_array = data[r, 1]
        for (j, tuple) in enumerate(tuple_array)
            for (i, value) in enumerate(tuple)
                t_quad_cost[r, 1, i, j] = value
            end
        end
    end
    return t_quad_cost
end

transform_array_for_hdf(
    data::SortedDict{Dates.DateTime, Vector{T}}) where {T <: FunctionData} =
    throw(ArgumentError("Not currently implemented for $T"))

transform_array_for_hdf(data::Vector{T}) where {T <: FunctionData} =
    throw(ArgumentError("Not currently implemented for $T"))
