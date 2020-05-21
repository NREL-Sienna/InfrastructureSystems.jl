#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct PiecewiseCostInternal <: ForecastInternal
        label::String
        resolution::Dates.Period
        initial_time::Dates.DateTime
        break_points::Int
        time_series_uuid::UUIDs.UUID
        horizon::Int
        internal::InfrastructureSystemsInternal
    end

A forecast for piecewise cost function data field in a Component.

# Arguments
- `label::String`: label of component parameter forecasted
- `resolution::Dates.Period`
- `initial_time::Dates.DateTime`: forecast availability time
- `break_points::Int`: Number of break points
- `time_series_uuid::UUIDs.UUID`: reference to time series data; timestamp - scalingfactor
- `horizon::Int`: length of this forecast
- `internal::InfrastructureSystemsInternal`
"""
mutable struct PiecewiseCostInternal <: ForecastInternal
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

function PiecewiseCostInternal(label, resolution, initial_time, break_points, time_series_uuid, horizon, )
    PiecewiseCostInternal(label, resolution, initial_time, break_points, time_series_uuid, horizon, InfrastructureSystemsInternal(), )
end

function PiecewiseCostInternal(; label, resolution, initial_time, break_points, time_series_uuid, horizon, )
    PiecewiseCostInternal(label, resolution, initial_time, break_points, time_series_uuid, horizon, )
end

"""Get PiecewiseCostInternal label."""
get_label(value::PiecewiseCostInternal) = value.label
"""Get PiecewiseCostInternal resolution."""
get_resolution(value::PiecewiseCostInternal) = value.resolution
"""Get PiecewiseCostInternal initial_time."""
get_initial_time(value::PiecewiseCostInternal) = value.initial_time
"""Get PiecewiseCostInternal break_points."""
get_break_points(value::PiecewiseCostInternal) = value.break_points
"""Get PiecewiseCostInternal time_series_uuid."""
get_time_series_uuid(value::PiecewiseCostInternal) = value.time_series_uuid
"""Get PiecewiseCostInternal horizon."""
get_horizon(value::PiecewiseCostInternal) = value.horizon
"""Get PiecewiseCostInternal internal."""
get_internal(value::PiecewiseCostInternal) = value.internal

"""Set PiecewiseCostInternal label."""
set_label!(value::PiecewiseCostInternal, val::String) = value.label = val
"""Set PiecewiseCostInternal resolution."""
set_resolution!(value::PiecewiseCostInternal, val::Dates.Period) = value.resolution = val
"""Set PiecewiseCostInternal initial_time."""
set_initial_time!(value::PiecewiseCostInternal, val::Dates.DateTime) = value.initial_time = val
"""Set PiecewiseCostInternal break_points."""
set_break_points!(value::PiecewiseCostInternal, val::Int) = value.break_points = val
"""Set PiecewiseCostInternal time_series_uuid."""
set_time_series_uuid!(value::PiecewiseCostInternal, val::UUIDs.UUID) = value.time_series_uuid = val
"""Set PiecewiseCostInternal horizon."""
set_horizon!(value::PiecewiseCostInternal, val::Int) = value.horizon = val
"""Set PiecewiseCostInternal internal."""
set_internal!(value::PiecewiseCostInternal, val::InfrastructureSystemsInternal) = value.internal = val
