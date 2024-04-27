"""
Attribute to store Geographic Information about the system components
"""
struct GeographicInfo <: SupplementalAttribute
    geo_json::Dict{String, Any}
    internal::InfrastructureSystemsInternal
end

function GeographicInfo(;
    geo_json::Dict{String, <:Any} = Dict{String, Any}(),
    internal = InfrastructureSystemsInternal(),
)
    return GeographicInfo(geo_json, internal)
end

get_geo_json(geo::GeographicInfo) = geo.geo_json
get_internal(geo::GeographicInfo) = geo.internal
get_uuid(geo::GeographicInfo) = get_uuid(get_internal(geo))
