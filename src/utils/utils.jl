import InteractiveUtils: subtypes

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

"""Recursively builds a vector of subtypes."""
function _get_all_concrete_subtypes(::Type{T}, sub_types::Vector{DataType}) where {T}
    for sub_type in subtypes(T)
        if isconcretetype(sub_type)
            push!(sub_types, sub_type)
        elseif isabstracttype(sub_type)
            _get_all_concrete_subtypes(sub_type, sub_types)
        end
    end

    return nothing
end

"""Returns an array of concrete types that are direct subtypes of T."""
function get_concrete_subtypes(::Type{T}) where {T}
    return [x for x in subtypes(T) if isconcretetype(x)]
end

"""Returns an array of abstract types that are direct subtypes of T."""
function get_abstract_subtypes(::Type{T}) where {T}
    return [x for x in subtypes(T) if isabstracttype(x)]
end

"""Returns an array of all super types of T."""
function supertypes(::Type{T}, types = []) where {T}
    super = supertype(T)
    push!(types, super)
    if super == Any
        return types
    end

    supertypes(super, types)
end

"""Converts a DataType to a Symbol, stripping off the module name(s)."""
function type_to_symbol(data_type::DataType)
    return Symbol(strip_module_name(string(data_type)))
end

"""Strips the module name off of a type."""
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
Return a Tuple of type and parameter types for cases where a parametric type has been
encoded as a string. If the type is not parameterized then just return the type.
"""
function separate_type_and_parameter_types(name::String)
    parameters = Vector{String}()
    index_start_brace = findfirst("{", name)
    if isnothing(index_start_brace)
        type_str = name
    else
        type_str = name[1:(index_start_brace.start - 1)]
        index_close_brace = findfirst("}", name)
        @assert index_start_brace.start < index_close_brace.start
        for x in
            split(name[(index_start_brace.start + 1):(index_close_brace.start - 1)], ",")
            push!(parameters, strip(x))
        end
    end

    return (type_str, parameters)
end

"""Converts an object deserialized from JSON into a Julia type, such as NamedTuple,
to an instance of T. Similar to Base.convert, but not a viable replacement.
"""
function convert_type(::Type{T}, data::Any) where {T}
    # Improvement: implement the conversion logic. Need to recursively convert fieldnames
    # to fieldtypes, collect the values, and pass them to T(). Also handle literals.
    # The JSON2 library already handles almost all of the cases.
    #if data isa AbstractString && T <: AbstractString
    if T <: AbstractString
        return T(data)
    end

    return JSON2.read(JSON2.write(data), T)
end

"""
    validate_exported_names(mod::Module)

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
Recursively compares immutable struct values by performing == on each field in the struct.
When performing == on values of immutable structs Julia will perform === on
each field.  This will return false if any field is mutable even if the
contents are the same.  So, comparison of any InfrastructureSystems type with an array
will fail.

This is an unresolved Julia issue. Refer to
https://github.com/JuliaLang/julia/issues/4648.

An option is to overload == for all subtypes of PowerSystemType. That may not be
appropriate in all cases. Until the Julia developers decide on a solution, this
function is provided for convenience for specific comparisons.

"""
function compare_values(x::T, y::T)::Bool where {T}
    match = true
    fields = fieldnames(T)
    if isempty(fields)
        match = x == y
    else
        for fieldname in fields
            if T <: Forecasts && fieldname == :time_series_storage
                # This gets validated at SystemData. Don't repeat for each component.
                continue
            end
            val1 = getfield(x, fieldname)
            val2 = getfield(y, fieldname)
            if !isempty(fieldnames(typeof(val1)))
                if !compare_values(val1, val2)
                    @debug "values do not match" T fieldname val1 val2
                    match = false
                    break
                end
            elseif val1 isa AbstractArray
                if !compare_values(val1, val2)
                    match = false
                end
            else
                if val1 != val2
                    @debug "values do not match" T fieldname val1 val2
                    match = false
                    break
                end
            end
        end
    end

    return match
end

function compare_values(x::Vector{T}, y::Vector{T})::Bool where {T}
    if length(x) != length(y)
        @debug "lengths do not match" T length(x) length(y)
        return false
    end

    for i in range(1, length = length(x))
        if !compare_values(x[i], y[i])
            @debug "values do not match" typeof(x[i]) i x[i] y[i]
            return false
        end
    end

    return true
end

function compare_values(x::Dict, y::Dict)::Bool
    keys_x = Set(keys(x))
    keys_y = Set(keys(y))
    if keys_x != keys_y
        @debug "keys don't match" keys_x keys_y
        return false
    end

    for key in keys_x
        if !compare_values(x[key], y[key])
            @debug "values do not match" typeof(x[key]) key x[key] y[key]
            return false
        end
    end

    return true
end

function compare_values(x::T, y::U)::Bool where {T, U}
    # This is a catch-all for where where the types may not be identical but are close
    # enough.
    return x == y
end

"""
Macro to wrap Enum in a baremodule to keep the top level scope clean.
The macro name should be singular. The macro will create a module for access that is plural.

# Examples
```julia
@scoped_enum Fruit begin
    APPLE
    ORANGE
end

value = Fruits.APPLE

# Usage as a function parameter
foo(value::Fruits.Fruit) = nothing
```

"""
macro scoped_enum(T, args...)
    blk = esc(:(baremodule $(Symbol("$(T)s"))
    using Base: @enum
    @enum $T $(args...)
    end))
    return blk
end
