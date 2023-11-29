"""
Base type for structs that store infos

Required interface functions for subtypes:

  - get_internal()
  - get_components_uuid()
  - get_time_series_container()

Subtypes may contain time series, if no time series container is implemented return nothing
"""
struct InfrastructureSystemsGeo <: InfrastructureSystemsInfo
    geo_json::Dict{String, Any}
    components_uuid::Vector{UUIDs.UUID}
    internal::InfrastructureSystemsInternal
end

function InfrastructureSystemsGeo(;
    geo_json::Dict{String, Any} = Dict{String, Any}(),
    components_uuid::Vector{UUIDs.UUID} = Vector{UUIDs.UUID}())
    return InfrastructureSystemsGeo(geo_json, components_uuid, InfrastructureSystemsInternal())
end

get_geo_json(geo::InfrastructureSystemsGeo) = geo.geo_json
get_internal(geo::InfrastructureSystemsGeo) = geo.internal
get_uuid(geo::InfrastructureSystemsGeo) = get_uuid(get_internal(geo))
get_time_series_container(::InfrastructureSystemsGeo) = nothing
