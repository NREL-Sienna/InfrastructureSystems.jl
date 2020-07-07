
import UUIDs

abstract type UnitsData end

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
