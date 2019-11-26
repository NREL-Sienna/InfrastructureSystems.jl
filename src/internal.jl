
import UUIDs

"""Internal storage common to InfrastructureSystems types."""
mutable struct InfrastructureSystemsInternal
    uuid::Base.UUID
    ext::Union{Nothing, Dict{String, Any}}
end

"""
Creates PowerSystemInternal with a UUID.
"""
InfrastructureSystemsInternal() = InfrastructureSystemsInternal(UUIDs.uuid4(), nothing)

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
Gets the UUID for any PowerSystemType.
"""
function get_uuid(obj::InfrastructureSystemsType)::Base.UUID
    return obj.internal.uuid
end
