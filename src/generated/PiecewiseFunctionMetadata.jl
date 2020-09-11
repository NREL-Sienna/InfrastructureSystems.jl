#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct PiecewiseFunctionMetadata <: TimeSeriesMetadata
        label::String
        resolution::Dates.Period
        initial_time::Dates.DateTime
        break_points::Int
        time_series_uuid::UUIDs.UUID
        horizon::Int
        internal::InfrastructureSystemsInternal
    end

A time series for piecewise function data field in a Component.

# Arguments
- `label::String`: user-defined label
- `resolution::Dates.Period`
- `initial_time::Dates.DateTime`: time series availability time
- `break_points::Int`: Number of break points
- `time_series_uuid::UUIDs.UUID`: reference to time series data; timestamp - scalingfactor
- `horizon::Int`: length of this time series
- `internal::InfrastructureSystemsInternal`
"""
mutable struct PiecewiseFunctionMetadata <: TimeSeriesMetadata
    "user-defined label"
    label::String
    resolution::Dates.Period
    "time series availability time"
    initial_time::Dates.DateTime
    "Number of break points"
    break_points::Int
    "reference to time series data; timestamp - scalingfactor"
    time_series_uuid::UUIDs.UUID
    "length of this time series"
    horizon::Int
    internal::InfrastructureSystemsInternal
end

function PiecewiseFunctionMetadata(label, resolution, initial_time, break_points, time_series_uuid, horizon, )
    PiecewiseFunctionMetadata(label, resolution, initial_time, break_points, time_series_uuid, horizon, InfrastructureSystemsInternal(), )
end

function PiecewiseFunctionMetadata(; label, resolution, initial_time, break_points, time_series_uuid, horizon, internal=InfrastructureSystemsInternal(), )
    PiecewiseFunctionMetadata(label, resolution, initial_time, break_points, time_series_uuid, horizon, internal, )
end

"""Get [`PiecewiseFunctionMetadata`](@ref) `label`."""
get_label(value::PiecewiseFunctionMetadata) = value.label
"""Get [`PiecewiseFunctionMetadata`](@ref) `resolution`."""
get_resolution(value::PiecewiseFunctionMetadata) = value.resolution
"""Get [`PiecewiseFunctionMetadata`](@ref) `initial_time`."""
get_initial_time(value::PiecewiseFunctionMetadata) = value.initial_time
"""Get [`PiecewiseFunctionMetadata`](@ref) `break_points`."""
get_break_points(value::PiecewiseFunctionMetadata) = value.break_points
"""Get [`PiecewiseFunctionMetadata`](@ref) `time_series_uuid`."""
get_time_series_uuid(value::PiecewiseFunctionMetadata) = value.time_series_uuid
"""Get [`PiecewiseFunctionMetadata`](@ref) `horizon`."""
get_horizon(value::PiecewiseFunctionMetadata) = value.horizon
"""Get [`PiecewiseFunctionMetadata`](@ref) `internal`."""
get_internal(value::PiecewiseFunctionMetadata) = value.internal

"""Set [`PiecewiseFunctionMetadata`](@ref) `label`."""
set_label!(value::PiecewiseFunctionMetadata, val) = value.label = val
"""Set [`PiecewiseFunctionMetadata`](@ref) `resolution`."""
set_resolution!(value::PiecewiseFunctionMetadata, val) = value.resolution = val
"""Set [`PiecewiseFunctionMetadata`](@ref) `initial_time`."""
set_initial_time!(value::PiecewiseFunctionMetadata, val) = value.initial_time = val
"""Set [`PiecewiseFunctionMetadata`](@ref) `break_points`."""
set_break_points!(value::PiecewiseFunctionMetadata, val) = value.break_points = val
"""Set [`PiecewiseFunctionMetadata`](@ref) `time_series_uuid`."""
set_time_series_uuid!(value::PiecewiseFunctionMetadata, val) = value.time_series_uuid = val
"""Set [`PiecewiseFunctionMetadata`](@ref) `horizon`."""
set_horizon!(value::PiecewiseFunctionMetadata, val) = value.horizon = val
"""Set [`PiecewiseFunctionMetadata`](@ref) `internal`."""
set_internal!(value::PiecewiseFunctionMetadata, val) = value.internal = val

