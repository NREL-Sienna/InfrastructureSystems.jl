"""
Attribute to store Geographic Information about the system components
"""
struct GeographicInfo <: SupplementalAttribute
    geo_json::Dict{String, Any}
    component_uuids::ComponentUUIDs
    internal::InfrastructureSystemsInternal
end

function GeographicInfo(;
    geo_json::Dict{String, <:Any} = Dict{String, Any}(),
    component_uuids::ComponentUUIDs = ComponentUUIDs(),
    internal = InfrastructureSystemsInternal(),
)
    return GeographicInfo(geo_json, component_uuids, internal)
end

get_geo_json(geo::GeographicInfo) = geo.geo_json
get_internal(geo::GeographicInfo) = geo.internal
get_uuid(geo::GeographicInfo) = get_uuid(get_internal(geo))
get_time_series_container(::GeographicInfo) = nothing
get_component_uuids(geo::GeographicInfo) = geo.component_uuids
