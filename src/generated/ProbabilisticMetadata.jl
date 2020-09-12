#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct ProbabilisticMetadata <: TimeSeriesMetadata
        label::String
        resolution::Dates.Period
        initial_time::Dates.DateTime
        percentiles::Vector{Float64}
        time_series_uuid::UUIDs.UUID
        horizon::Int
        scaling_factor_multiplier::Union{Nothing, Function}
        internal::InfrastructureSystemsInternal
    end

A Probabilistic time series for a particular data field in a Component.

# Arguments
- `label::String`: user-defined label
- `resolution::Dates.Period`
- `initial_time::Dates.DateTime`: time series availability time
- `percentiles::Vector{Float64}`: Percentiles for the probabilistic time series
- `time_series_uuid::UUIDs.UUID`: reference to time series data
- `horizon::Int`: length of this time series
- `scaling_factor_multiplier::Union{Nothing, Function}`: Applicable when the time series data are scaling factors. Called on the associated component to convert the values.
- `internal::InfrastructureSystemsInternal`
"""
mutable struct ProbabilisticMetadata <: TimeSeriesMetadata
    "user-defined label"
    label::String
    resolution::Dates.Period
    "time series availability time"
    initial_time::Dates.DateTime
    "Percentiles for the probabilistic time series"
    percentiles::Vector{Float64}
    "reference to time series data"
    time_series_uuid::UUIDs.UUID
    "length of this time series"
    horizon::Int
    "Applicable when the time series data are scaling factors. Called on the associated component to convert the values."
    scaling_factor_multiplier::Union{Nothing, Function}
    internal::InfrastructureSystemsInternal
end

function ProbabilisticMetadata(label, resolution, initial_time, percentiles, time_series_uuid, horizon, scaling_factor_multiplier=nothing, )
    ProbabilisticMetadata(label, resolution, initial_time, percentiles, time_series_uuid, horizon, scaling_factor_multiplier, InfrastructureSystemsInternal(), )
end

function ProbabilisticMetadata(; label, resolution, initial_time, percentiles, time_series_uuid, horizon, scaling_factor_multiplier=nothing, internal=InfrastructureSystemsInternal(), )
    ProbabilisticMetadata(label, resolution, initial_time, percentiles, time_series_uuid, horizon, scaling_factor_multiplier, internal, )
end

"""Get [`ProbabilisticMetadata`](@ref) `label`."""
get_label(value::ProbabilisticMetadata) = value.label
"""Get [`ProbabilisticMetadata`](@ref) `resolution`."""
get_resolution(value::ProbabilisticMetadata) = value.resolution
"""Get [`ProbabilisticMetadata`](@ref) `initial_time`."""
get_initial_time(value::ProbabilisticMetadata) = value.initial_time
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

"""Set [`ProbabilisticMetadata`](@ref) `label`."""
set_label!(value::ProbabilisticMetadata, val) = value.label = val
"""Set [`ProbabilisticMetadata`](@ref) `resolution`."""
set_resolution!(value::ProbabilisticMetadata, val) = value.resolution = val
"""Set [`ProbabilisticMetadata`](@ref) `initial_time`."""
set_initial_time!(value::ProbabilisticMetadata, val) = value.initial_time = val
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

