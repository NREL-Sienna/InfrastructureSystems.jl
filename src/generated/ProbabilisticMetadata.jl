#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct ProbabilisticMetadata <: ForecastMetadata
        name::String
        initial_timestamp::Dates.DateTime
        resolution::Dates.Period
        interval::Dates.Period
        count::Int
        percentiles::Vector{Float64}
        time_series_uuid::UUIDs.UUID
        horizon::Int
        scaling_factor_multiplier::Union{Nothing, Function}
        internal::InfrastructureSystemsInternal
    end

A Probabilistic forecast for a particular data field in a Component.

# Arguments
- `name::String`: user-defined name
- `initial_timestamp::Dates.DateTime`: time series availability time
- `resolution::Dates.Period`
- `interval::Dates.Period`: time step between forecast windows
- `count::Int`: number of forecast windows
- `percentiles::Vector{Float64}`: Percentiles for the probabilistic forecast
- `time_series_uuid::UUIDs.UUID`: reference to time series data
- `horizon::Int`: length of this time series
- `scaling_factor_multiplier::Union{Nothing, Function}`: Applicable when the time series data are scaling factors. Called on the associated component to convert the values.
- `internal::InfrastructureSystemsInternal`
"""
mutable struct ProbabilisticMetadata <: ForecastMetadata
    "user-defined name"
    name::String
    "time series availability time"
    initial_timestamp::Dates.DateTime
    resolution::Dates.Period
    "time step between forecast windows"
    interval::Dates.Period
    "number of forecast windows"
    count::Int
    "Percentiles for the probabilistic forecast"
    percentiles::Vector{Float64}
    "reference to time series data"
    time_series_uuid::UUIDs.UUID
    "length of this time series"
    horizon::Int
    "Applicable when the time series data are scaling factors. Called on the associated component to convert the values."
    scaling_factor_multiplier::Union{Nothing, Function}
    internal::InfrastructureSystemsInternal
end

function ProbabilisticMetadata(name, initial_timestamp, resolution, interval, count, percentiles, time_series_uuid, horizon, scaling_factor_multiplier=nothing, )
    ProbabilisticMetadata(name, initial_timestamp, resolution, interval, count, percentiles, time_series_uuid, horizon, scaling_factor_multiplier, InfrastructureSystemsInternal(), )
end

function ProbabilisticMetadata(; name, initial_timestamp, resolution, interval, count, percentiles, time_series_uuid, horizon, scaling_factor_multiplier=nothing, internal=InfrastructureSystemsInternal(), )
    ProbabilisticMetadata(name, initial_timestamp, resolution, interval, count, percentiles, time_series_uuid, horizon, scaling_factor_multiplier, internal, )
end

"""Get [`ProbabilisticMetadata`](@ref) `name`."""
get_name(value::ProbabilisticMetadata) = value.name
"""Get [`ProbabilisticMetadata`](@ref) `initial_timestamp`."""
get_initial_timestamp(value::ProbabilisticMetadata) = value.initial_timestamp
"""Get [`ProbabilisticMetadata`](@ref) `resolution`."""
get_resolution(value::ProbabilisticMetadata) = value.resolution
"""Get [`ProbabilisticMetadata`](@ref) `interval`."""
get_interval(value::ProbabilisticMetadata) = value.interval
"""Get [`ProbabilisticMetadata`](@ref) `count`."""
get_count(value::ProbabilisticMetadata) = value.count
"""Get [`ProbabilisticMetadata`](@ref) `percentiles`."""
get_percentiles(value::ProbabilisticMetadata) = value.percentiles
"""Get [`ProbabilisticMetadata`](@ref) `time_series_uuid`."""
get_time_series_uuid(value::ProbabilisticMetadata) = value.time_series_uuid
"""Get [`ProbabilisticMetadata`](@ref) `horizon`."""
get_horizon(value::ProbabilisticMetadata) = value.horizon
"""Get [`ProbabilisticMetadata`](@ref) `scaling_factor_multiplier`."""
get_scaling_factor_multiplier(value::ProbabilisticMetadata) = value.scaling_factor_multiplier
"""Get [`ProbabilisticMetadata`](@ref) `internal`."""
get_internal(value::ProbabilisticMetadata) = value.internal

"""Set [`ProbabilisticMetadata`](@ref) `name`."""
set_name!(value::ProbabilisticMetadata, val) = value.name = val
"""Set [`ProbabilisticMetadata`](@ref) `initial_timestamp`."""
set_initial_timestamp!(value::ProbabilisticMetadata, val) = value.initial_timestamp = val
"""Set [`ProbabilisticMetadata`](@ref) `resolution`."""
set_resolution!(value::ProbabilisticMetadata, val) = value.resolution = val
"""Set [`ProbabilisticMetadata`](@ref) `interval`."""
set_interval!(value::ProbabilisticMetadata, val) = value.interval = val
"""Set [`ProbabilisticMetadata`](@ref) `count`."""
set_count!(value::ProbabilisticMetadata, val) = value.count = val
"""Set [`ProbabilisticMetadata`](@ref) `percentiles`."""
set_percentiles!(value::ProbabilisticMetadata, val) = value.percentiles = val
"""Set [`ProbabilisticMetadata`](@ref) `time_series_uuid`."""
set_time_series_uuid!(value::ProbabilisticMetadata, val) = value.time_series_uuid = val
"""Set [`ProbabilisticMetadata`](@ref) `horizon`."""
set_horizon!(value::ProbabilisticMetadata, val) = value.horizon = val
"""Set [`ProbabilisticMetadata`](@ref) `scaling_factor_multiplier`."""
set_scaling_factor_multiplier!(value::ProbabilisticMetadata, val) = value.scaling_factor_multiplier = val
"""Set [`ProbabilisticMetadata`](@ref) `internal`."""
set_internal!(value::ProbabilisticMetadata, val) = value.internal = val

