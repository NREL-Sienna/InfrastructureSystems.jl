"""
Base type for structs that store attributes

Required interface functions for subtypes:

  - get_internal()
  - get_components_uuids()
  - get_time_series_container()

Subtypes may contain time series, if no time series container is implemented return nothing
"""
struct GeographicInfo <: InfrastructureSystemsSupplementalAttribute
    geo_json::Dict{String, Any}
    components_uuids::Set{UUIDs.UUID}
    internal::InfrastructureSystemsInternal
end

function GeographicInfo(;
    geo_json::Dict{String, Any}=Dict{String, Any}(),
    components_uuids::Set{UUIDs.UUID}=Set{UUIDs.UUID}(),
)
    return GeographicInfo(
        geo_json,
        components_uuid,
        InfrastructureSystemsInternal(),
    )
end

get_geo_json(geo::GeographicInfo) = geo.geo_json
get_internal(geo::GeographicInfo) = geo.internal
get_uuid(geo::GeographicInfo) = get_uuid(get_internal(geo))
get_time_series_container(::GeographicInfo) = nothing
get_components_uuids(geo::GeographicInfo) = geo.components_uuid
