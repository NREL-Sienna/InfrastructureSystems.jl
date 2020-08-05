#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct PiecewiseFunctionInternal <: ForecastInternal
        label::String
        resolution::Dates.Period
        initial_time::Dates.DateTime
        break_points::Int
        time_series_uuid::UUIDs.UUID
        horizon::Int
        internal::InfrastructureSystemsInternal
    end

A forecast for piecewise function data field in a Component.

# Arguments
- `label::String`: label of component parameter forecasted
- `resolution::Dates.Period`
- `initial_time::Dates.DateTime`: forecast availability time
- `break_points::Int`: Number of break points
- `time_series_uuid::UUIDs.UUID`: reference to time series data; timestamp - scalingfactor
- `horizon::Int`: length of this forecast
- `internal::InfrastructureSystemsInternal`
"""
mutable struct PiecewiseFunctionInternal <: ForecastInternal
    "label of component parameter forecasted"
    label::String
    resolution::Dates.Period
    "forecast availability time"
    initial_time::Dates.DateTime
    "Number of break points"
    break_points::Int
    "reference to time series data; timestamp - scalingfactor"
    time_series_uuid::UUIDs.UUID
    "length of this forecast"
    horizon::Int
    internal::InfrastructureSystemsInternal
end

function PiecewiseFunctionInternal(label, resolution, initial_time, break_points, time_series_uuid, horizon, )
    PiecewiseFunctionInternal(label, resolution, initial_time, break_points, time_series_uuid, horizon, InfrastructureSystemsInternal(), )
end

function PiecewiseFunctionInternal(; label, resolution, initial_time, break_points, time_series_uuid, horizon, )
    PiecewiseFunctionInternal(label, resolution, initial_time, break_points, time_series_uuid, horizon, )
end

"""Get PiecewiseFunctionInternal label."""
get_label(value::PiecewiseFunctionInternal) = value.label
"""Get PiecewiseFunctionInternal resolution."""
get_resolution(value::PiecewiseFunctionInternal) = value.resolution
"""Get PiecewiseFunctionInternal initial_time."""
get_initial_time(value::PiecewiseFunctionInternal) = value.initial_time
"""Get PiecewiseFunctionInternal break_points."""
get_break_points(value::PiecewiseFunctionInternal) = value.break_points
"""Get PiecewiseFunctionInternal time_series_uuid."""
get_time_series_uuid(value::PiecewiseFunctionInternal) = value.time_series_uuid
"""Get PiecewiseFunctionInternal horizon."""
get_horizon(value::PiecewiseFunctionInternal) = value.horizon
"""Get PiecewiseFunctionInternal internal."""
get_internal(value::PiecewiseFunctionInternal) = value.internal

"""Set PiecewiseFunctionInternal label."""
set_label!(value::PiecewiseFunctionInternal, val) = value.label = val
"""Set PiecewiseFunctionInternal resolution."""
set_resolution!(value::PiecewiseFunctionInternal, val) = value.resolution = val
"""Set PiecewiseFunctionInternal initial_time."""
set_initial_time!(value::PiecewiseFunctionInternal, val) = value.initial_time = val
"""Set PiecewiseFunctionInternal break_points."""
set_break_points!(value::PiecewiseFunctionInternal, val) = value.break_points = val
"""Set PiecewiseFunctionInternal time_series_uuid."""
set_time_series_uuid!(value::PiecewiseFunctionInternal, val) = value.time_series_uuid = val
"""Set PiecewiseFunctionInternal horizon."""
set_horizon!(value::PiecewiseFunctionInternal, val) = value.horizon = val
"""Set PiecewiseFunctionInternal internal."""
set_internal!(value::PiecewiseFunctionInternal, val) = value.internal = val
