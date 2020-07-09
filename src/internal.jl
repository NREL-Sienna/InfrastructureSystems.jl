
import UUIDs

abstract type UnitsData end

@enum UnitSystem begin
    SYSTEM_BASE
    DEVICE_BASE
    NATURAL_UNITS
end

struct SystemUnitsSettings <: UnitsData
    base_value::Float64
    unit_system::UnitSystem
end

"""Internal storage common to InfrastructureSystems types."""
mutable struct InfrastructureSystemsInternal
    uuid::Base.UUID
    units_info::Union{Nothing, UnitsData}
    ext::Union{Nothing, Dict{String, Any}}
end

"""
Creates PowerSystemInternal with a new UUID.
"""
InfrastructureSystemsInternal() =
    InfrastructureSystemsInternal(UUIDs.uuid4(), nothing, nothing)

"""
Creates PowerSystemInternal with an existing UUID.
"""
InfrastructureSystemsInternal(u::UUIDs.UUID) =
    InfrastructureSystemsInternal(u, nothing, nothing)

"""
Return a user-modifiable dictionary to store extra information.
"""
function get_ext(obj::InfrastructureSystemsInternal)
    if isnothing(obj.ext)
        obj.ext = Dict{String, Any}()
    end

    return obj.ext
end

"""
Clear any value stored in ext.
"""
function clear_ext(obj::InfrastructureSystemsInternal)
    obj.ext = nothing
end

get_uuid(internal::InfrastructureSystemsInternal) = internal.uuid

"""
Gets the UUID for any PowerSystemType.
"""
function get_uuid(obj::InfrastructureSystemsType)
    return get_internal(obj).uuid
end

"""
Assign a new UUID.
"""
function assign_new_uuid!(obj::InfrastructureSystemsType)
    get_internal(obj).uuid = UUIDs.uuid4()
end

function JSON2.write(io::IO, internal::InfrastructureSystemsInternal)
    return JSON2.write(io, encode_for_json(internal))
end

function JSON2.write(internal::InfrastructureSystemsInternal)
    return JSON2.write(encode_for_json(internal))
end

function encode_for_json(internal::InfrastructureSystemsInternal)
    fields = fieldnames(InfrastructureSystemsInternal)
    final_fields = Vector{Symbol}()
    vals = []

    for field in fields
        val = getfield(internal, field)
        # reset the units data since this is a struct related to the system the components is
        # added which is resolved later in the de-serialization.
        if val isa UnitsData
            val = nothing
        end
        push!(vals, val)
        push!(final_fields, field)
    end

    return NamedTuple{Tuple(final_fields)}(vals)
end
