"""
Base type for structs that store infos

Required interface functions for subtypes:

  - get_internal()

Optional interface functions:

  - get_time_series_container()

Subtypes may contain time series.
"""
struct InfrastructureSystemsGeo <: InfrastructureSystemsInfo
    geo_json::Dict{String, Any}
    internal::InfrastructureSystemsInternal
end
