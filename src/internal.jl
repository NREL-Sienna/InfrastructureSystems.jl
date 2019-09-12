
import UUIDs

"""Internal storage common to InfrastructureSystems types."""
struct InfrastructureSystemsInternal
    uuid::Base.UUID
end

"""Creates PowerSystemInternal with a UUID."""
InfrastructureSystemsInternal() = InfrastructureSystemsInternal(UUIDs.uuid4())

"""Gets the UUID for any PowerSystemType."""
function get_uuid(obj::InfrastructureSystemsType)::Base.UUID
    return obj.internal.uuid
end
