"""
Base type for structs that store infos

Required interface functions for subtypes:

  - get_internal()
  - get_components_uuid()

Subtypes may contain time series.
"""
struct InfrastructureSystemsGeo <: InfrastructureSystemsInfo
    geo_json::Dict{String, Any}
    components_uuid::Vector{UUIDs.UUID}
    internal::InfrastructureSystemsInternal
end

get_internal(::InfrastructureSystemsGeo) = geo.internal
get_uuid(geo::InfrastructureSystemsGeo) = get_uuid(get_internal(geo))
get_geo_json(geo::InfrastructureSystemsGeo) = geo.geo_json
