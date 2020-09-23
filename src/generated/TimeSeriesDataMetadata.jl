#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct TimeSeriesDataMetadata <: TimeSeriesMetadata
        label::String
        resolution::Dates.Period
        initial_time::Dates.DateTime
        time_series_uuid::UUIDs.UUID
        length::Int
        scaling_factor_multiplier::Union{Nothing, Function}
        internal::InfrastructureSystemsInternal
    end

A TimeSeries Data object in a.

# Arguments
- `label::String`: user-defined label
- `resolution::Dates.Period`
- `initial_time::Dates.DateTime`: time series availability time
- `time_series_uuid::UUIDs.UUID`: reference to time series data
- `length::Int`: length of this time series
- `scaling_factor_multiplier::Union{Nothing, Function}`: Applicable when the time series data are scaling factors. Called on the associated component to convert the values.
- `internal::InfrastructureSystemsInternal`
"""
mutable struct TimeSeriesDataMetadata <: TimeSeriesMetadata
    "user-defined label"
    label::String
    resolution::Dates.Period
    "time series availability time"
    initial_time::Dates.DateTime
    "reference to time series data"
    time_series_uuid::UUIDs.UUID
    "length of this time series"
    length::Int
    "Applicable when the time series data are scaling factors. Called on the associated component to convert the values."
    scaling_factor_multiplier::Union{Nothing, Function}
    internal::InfrastructureSystemsInternal
end

function TimeSeriesDataMetadata(label, resolution, initial_time, time_series_uuid, length, scaling_factor_multiplier=nothing, )
    TimeSeriesDataMetadata(label, resolution, initial_time, time_series_uuid, length, scaling_factor_multiplier, InfrastructureSystemsInternal(), )
end

function TimeSeriesDataMetadata(; label, resolution, initial_time, time_series_uuid, length, scaling_factor_multiplier=nothing, internal=InfrastructureSystemsInternal(), )
    TimeSeriesDataMetadata(label, resolution, initial_time, time_series_uuid, length, scaling_factor_multiplier, internal, )
end

"""Get [`TimeSeriesDataMetadata`](@ref) `label`."""
get_label(value::TimeSeriesDataMetadata) = value.label
"""Get [`TimeSeriesDataMetadata`](@ref) `resolution`."""
get_resolution(value::TimeSeriesDataMetadata) = value.resolution
"""Get [`TimeSeriesDataMetadata`](@ref) `initial_time`."""
get_initial_time(value::TimeSeriesDataMetadata) = value.initial_time
"""Get [`TimeSeriesDataMetadata`](@ref) `time_series_uuid`."""
get_time_series_uuid(value::TimeSeriesDataMetadata) = value.time_series_uuid
"""Get [`TimeSeriesDataMetadata`](@ref) `length`."""
get_length(value::TimeSeriesDataMetadata) = value.length
"""Get [`TimeSeriesDataMetadata`](@ref) `scaling_factor_multiplier`."""
get_scaling_factor_multiplier(value::TimeSeriesDataMetadata) = value.scaling_factor_multiplier
"""Get [`TimeSeriesDataMetadata`](@ref) `internal`."""
get_internal(value::TimeSeriesDataMetadata) = value.internal

"""Set [`TimeSeriesDataMetadata`](@ref) `label`."""
set_label!(value::TimeSeriesDataMetadata, val) = value.label = val
"""Set [`TimeSeriesDataMetadata`](@ref) `resolution`."""
set_resolution!(value::TimeSeriesDataMetadata, val) = value.resolution = val
"""Set [`TimeSeriesDataMetadata`](@ref) `initial_time`."""
set_initial_time!(value::TimeSeriesDataMetadata, val) = value.initial_time = val
"""Set [`TimeSeriesDataMetadata`](@ref) `time_series_uuid`."""
set_time_series_uuid!(value::TimeSeriesDataMetadata, val) = value.time_series_uuid = val
"""Set [`TimeSeriesDataMetadata`](@ref) `length`."""
set_length!(value::TimeSeriesDataMetadata, val) = value.length = val
"""Set [`TimeSeriesDataMetadata`](@ref) `scaling_factor_multiplier`."""
set_scaling_factor_multiplier!(value::TimeSeriesDataMetadata, val) = value.scaling_factor_multiplier = val
"""Set [`TimeSeriesDataMetadata`](@ref) `internal`."""
set_internal!(value::TimeSeriesDataMetadata, val) = value.internal = val

get_horizon(val::TimeSeriesDataMetadata) = get_length(val)
