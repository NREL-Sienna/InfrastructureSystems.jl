# These will get encoded into each dictionary when a struct is serialized.
const METADATA_KEY = "__metadata"
const TYPE_KEY = "type"
const MODULE_KEY = "module"
const PARAMETERS_KEY = "parameters"
const CONSTRUCT_WITH_PARAMETERS_KEY = "construct_with_parameters"

"""
Serializes a InfrastructureSystemsType to a JSON file.
"""
function to_json(
    obj::T,
    filename::AbstractString;
    force = false,
) where {T <: InfrastructureSystemsType}
    if !force && isfile(filename)
        error("$file already exists. Set force=true to overwrite.")
    end
    result = open(filename, "w") do io
        return to_json(io, obj)
    end

    @info "Serialized $T to $filename"
    return result
end

"""
Serializes a InfrastructureSystemsType to a JSON string.
"""
function to_json(obj::T)::String where {T <: InfrastructureSystemsType}
    return JSON3.write(serialize(obj))
end

"""
Deserializes a InfrastructureSystemsType from a JSON filename.
"""
function from_json(::Type{T}, filename::String) where {T <: InfrastructureSystemsType}
    return open(filename) do io
        from_json(io, T)
    end
end

"""
Deserializes a InfrastructureSystemsType from String or IO.
"""
function from_json(io::Union{IO, String}, ::Type{T}) where {T <: InfrastructureSystemsType}
    return deserialize(T, JSON3.read(io, Dict))
end

"""
Serialize the Julia value into standard types that can be converted to non-Julia formats,
such as JSON. In cases where val is an instance of a struct, return a Dict. In cases where
val is a scalar value, return that value.
"""
function serialize(val::T) where {T <: InfrastructureSystemsType}
    @debug "serialize InfrastructureSystemsType" val T
    return serialize_struct(val)
end

function serialize(vals::Vector{T}) where {T <: InfrastructureSystemsType}
    @debug "serialize Vector{InfrastructureSystemsType}" vals T
    return serialize_struct.(vals)
end

function serialize_struct(val::T) where {T}
    @debug "serialize_struct" val T
    data = Dict(string(name) => serialize(getfield(val, name)) for name in fieldnames(T))
    add_serialization_metadata!(data, T)
    return data
end

"""
Add type information to the dictionary that can be used to deserialize the value.
"""
function add_serialization_metadata!(data::Dict, ::Type{T}) where {T}
    data[METADATA_KEY] = Dict{String, Any}(
        TYPE_KEY => string(nameof(T)),
        MODULE_KEY => string(parentmodule(T)),
    )
    if !isempty(T.parameters)
        data[METADATA_KEY][PARAMETERS_KEY] = string.(T.parameters)
    end

    return
end

"""
Return the type information for the serialized struct.
"""
get_serialization_metadata(data::Dict) = data[METADATA_KEY]

function get_type_from_serialization_data(data::Dict)
    return get_type_from_serialization_metadata(get_serialization_metadata(data))
end

function get_type_from_serialization_metadata(metadata::Dict)
    mod = Base.root_module(Base.__toplevel__, Symbol(metadata[MODULE_KEY]))
    base_type = getfield(mod, Symbol(metadata[TYPE_KEY]))
    if !get(metadata, CONSTRUCT_WITH_PARAMETERS_KEY, false)
        return base_type
    end

    # This has several limitations and is only a workaround for PSY.Reserve subtypes.
    # - each parameter must be in mod
    # - does not support nested parametrics.
    # Reserves should be fixed and then we can remove this hack.
    parameters = [getfield(mod, Symbol(x)) for x in metadata[PARAMETERS_KEY]]
    return base_type{parameters...}
end

# The default implementation allows any scalar type (or collection of scalar types) to
# work. The JSON library must be able to encode and decode anything passed here.

serialize(val::T) where {T} = val

"""
Deserialize an object from standard types stored in non-Julia formats, such as JSON, into
Julia types.
"""
function deserialize(::Type{T}, data::Dict) where {T <: InfrastructureSystemsType}
    @debug "deserialize InfrastructureSystemsType" T data
    return deserialize_struct(T, data)
end

function deserialize_struct(::Type{T}, data::Dict) where {T}
    vals = Dict{Symbol, Any}()
    for (field_name, field_type) in zip(fieldnames(T), fieldtypes(T))
        val = data[string(field_name)]
        if val isa Dict && haskey(val, METADATA_KEY)
            vals[field_name] = deserialize(get_type_from_serialization_data(val), val)
        else
            vals[field_name] = deserialize(field_type, val)
        end
    end

    return T(; vals...)
end

function deserialize(::Type{T}, data::Any) where {T}
    @debug "deserialize Any" T data
    return data
end

function deserialize(::Type{T}, data::Any) where {T <: AbstractFloat}
    return T(data)
end

function deserialize(::Type{T}, data::Dict) where {T <: NamedTuple}
    return T(key = data[string(key)] for key in fieldnames(T))
end

function deserialize(
    ::Type{T},
    data::Union{Nothing, Dict},
) where {T <: Union{Nothing, NamedTuple}}
    return isnothing(data) ? nothing : deserialize(T.b, data)
end

# Enables JSON serialization of Dates.Period.
# The default implementation fails because the field is defined as abstract.
# Encode the type when serializing so that the correct value can be deserialized.
function serialize(resolution::Dates.Period)
    return Dict(
        "value" => resolution.value,
        TYPE_KEY => strip_module_name(typeof(resolution)),
    )
end

function deserialize(::Type{Dates.Period}, data::Dict)
    return getfield(Dates, Symbol(data[TYPE_KEY]))(data["value"])
end

deserialize(::Type{Dates.DateTime}, val::AbstractString) = Dates.DateTime(val)

# The next methods fix serialization of UUIDs. The underlying type of a UUID is a UInt128.
# JSON tries to encode this as a number in JSON. Encoding integers greater than can
# be stored in a signed 64-bit integer sometimes does not work - at least when using
# JSON3. The number gets converted to a float in scientific notation, and so
# the UUID is truncated and essentially lost. These functions cause JSON to encode UUIDs as
# strings and then convert them back during deserialization.

serialize(uuid::Base.UUID) = Dict("value" => string(uuid))
serialize(uuids::Vector{Base.UUID}) = serialize.(uuids)
deserialize(::Type{Base.UUID}, data::Dict) = Base.UUID(data["value"])

serialize(value::Complex) = Dict("real" => real(value), "imag" => imag(value))
deserialize(::Type{Complex}, data::Dict) = Complex(data["real"], data["imag"])
deserialize(::Type{Complex{T}}, data::Dict) where {T} =
    Complex(T(data["real"]), T(data["imag"]))

deserialize(::Type{Vector{Symbol}}, data::Vector) = Symbol.(data)

"""
Deserialize a parametric type. The default implementation strips the parametric types and
calls the constructor with only the base type.
"""
function deserialize_parametric_type(
    ::Type{T},
    mod::Module,
    data::Dict,
) where {T <: InfrastructureSystemsType}
    return getfield(mod, Symbol(T.name))(; data...)
end
