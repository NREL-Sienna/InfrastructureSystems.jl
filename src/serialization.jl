
"""Serializes a InfrastructureSystemsType to a JSON file."""
function to_json(obj::T, filename::AbstractString) where {T <: InfrastructureSystemsType}
    result = open(filename, "w") do io
        return to_json(io, obj)
    end

    @info "Serialized $T to $filename"
    return result
end

"""Serializes a InfrastructureSystemsType to a JSON string."""
function to_json(obj::T)::String where {T <: InfrastructureSystemsType}
    return JSON2.write(obj)
end

"""JSON Serializes a InfrastructureSystemsType to an IO stream in JSON."""
function to_json(io::IO, obj::T) where {T <: InfrastructureSystemsType}
    return JSON2.write(io, obj)
end

"""Deserializes a InfrastructureSystemsType from a JSON filename."""
function from_json(::Type{T}, filename::String) where {T <: InfrastructureSystemsType}
    return open(filename) do io
        from_json(io, T)
    end
end

"""Deserializes a InfrastructureSystemsType from String or IO."""
function from_json(io::Union{IO, String}, ::Type{T}) where {T <: InfrastructureSystemsType}
    return JSON2.read(io, T)
end

"""Enables JSON deserialization of TimeSeries.TimeArray.
The default implementation fails because the data field is defined as an AbstractArray.
Deserialization can't determine the actual concrete type.
"""
function JSON2.read(io::IO, ::Type{T}) where {T <: TimeSeries.TimeArray}
    data = JSON2.read(io)
    timestamp = [Dates.DateTime(x) for x in data.timestamp]
    colnames = [Symbol(x) for x in data.colnames]
    dim2 = length(colnames)
    dim1 = Int(length(data.values) / dim2)

    for i in eachindex(data.values)
        data.values[i] = Float64(data.values[i])
    end

    if length(colnames) > 1
        vals = reshape(data.values, dim1, dim2)
    else
        vals = data.values
    end

    return TimeSeries.TimeArray(timestamp, vals, colnames)
end

"""Enables JSON deserialization of Dates.Period.
The default implementation fails because the field is defined as abstract.
Encode the type when serializing so that the correct value can be deserialized.
"""
function JSON2.write(resolution::Dates.Period)
    return JSON2.write(encode_for_json(resolution))
end

function JSON2.write(io::IO, resolution::Dates.Period)
    return JSON2.write(io, encode_for_json(resolution))
end

function encode_for_json(resolution::Dates.Period)
    return (value=resolution.value,
            unit=strip_module_name(string(typeof(resolution))))
end

function JSON2.read(io::IO, ::Type{T}) where {T <: Dates.Period}
    data = JSON2.read(io)
    return getfield(Dates, Symbol(data.unit))(data.value)
end

"""
The next few methods fix serialization of UUIDs. The underlying type of a UUID is a UInt128.
JSON2 tries to encode this as a number in JSON. Encoding integers greater than can
be stored in a signed 64-bit integer sometimes does not work - at least when using the
JSON2.@pretty option. The number gets converted to a float in scientific notation, and so
the UUID is truncated and essentially lost. These functions cause JSON2 to encode UUIDs as
strings and then convert them back during deserialization.
"""

function JSON2.write(uuid::Base.UUID)
    return JSON2.write(encode_for_json(uuid))
end

function JSON2.write(io::IO, uuid::Base.UUID)
    return JSON2.write(io, encode_for_json(uuid))
end

function JSON2.read(io::IO, ::Type{Base.UUID})
    data = JSON2.read(io)
    return Base.UUID(data.value)
end

function encode_for_json(uuid::Base.UUID)
    return (value=string(uuid),)
end

"""The next set of methods fix serialization for Complex numbers."""

function JSON2.write(value::Complex)
    return JSON2.write(encode_for_json(value))
end

function JSON2.write(io::IO, value::Complex)
    return JSON2.write(io, encode_for_json(value))
end

function JSON2.read(io::IO, ::Type{Complex})
    data = JSON2.read(io)
    return Complex(data.real, data.imag)
end

function encode_for_json(value::Complex)
    return (real=real(value), imag=imag(value))
end

# Refer to docstrings in services.jl.

function JSON2.write(io::IO, forecast::Forecast)
    return JSON2.write(io, encode_for_json(forecast))
end

function JSON2.write(forecast::Forecast)
    return JSON2.write(encode_for_json(forecast))
end

function encode_for_json(forecast::T) where T <: Forecast
    fields = [x for x in fieldnames(T) if x != :data]
    vals = []

    for name in fields
        if name == :data
            # The timeseries is stored within SystemForecasts.
            continue
        end
        val = getfield(forecast, name)
        if val isa InfrastructureSystemsType
            push!(vals, get_uuid(val))
        else
            push!(vals, val)
        end
    end

    push!(fields, :type)
    push!(vals, strip_module_name(string(T.name)))
    return NamedTuple{Tuple(fields)}(vals)
end
