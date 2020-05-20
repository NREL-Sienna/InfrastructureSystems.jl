#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct CostCoefficientInternal <: ForecastInternal
        label::String
        resolution::Dates.Period
        initial_time::Dates.DateTime
        break_points::Int64
        time_series_uuid::UUIDs.UUID
        horizon::Int
        internal::InfrastructureSystemsInternal
    end

A Discrete Scenario Based forecast for a particular data field in a Component.

# Arguments
- `label::String`: label of component parameter forecasted
- `resolution::Dates.Period`
- `initial_time::Dates.DateTime`: forecast availability time
- `break_points::Int64`: Number of break points
- `time_series_uuid::UUIDs.UUID`: reference to time series data; timestamp - scalingfactor
- `horizon::Int`: length of this forecast
- `internal::InfrastructureSystemsInternal`
"""
mutable struct CostCoefficientInternal <: ForecastInternal
    "label of component parameter forecasted"
    label::String
    resolution::Dates.Period
    "forecast availability time"
    initial_time::Dates.DateTime
    "Number of break points"
    break_points::Int64
    "reference to time series data; timestamp - scalingfactor"
    time_series_uuid::UUIDs.UUID
    "length of this forecast"
    horizon::Int
    internal::InfrastructureSystemsInternal
end

function CostCoefficientInternal(label, resolution, initial_time, break_points, time_series_uuid, horizon, )
    CostCoefficientInternal(label, resolution, initial_time, break_points, time_series_uuid, horizon, InfrastructureSystemsInternal(), )
end

function CostCoefficientInternal(; label, resolution, initial_time, break_points, time_series_uuid, horizon, )
    CostCoefficientInternal(label, resolution, initial_time, break_points, time_series_uuid, horizon, )
end

"""Get CostCoefficientInternal label."""
get_label(value::CostCoefficientInternal) = value.label
"""Get CostCoefficientInternal resolution."""
get_resolution(value::CostCoefficientInternal) = value.resolution
"""Get CostCoefficientInternal initial_time."""
get_initial_time(value::CostCoefficientInternal) = value.initial_time
"""Get CostCoefficientInternal break_points."""
get_break_points(value::CostCoefficientInternal) = value.break_points
"""Get CostCoefficientInternal time_series_uuid."""
get_time_series_uuid(value::CostCoefficientInternal) = value.time_series_uuid
"""Get CostCoefficientInternal horizon."""
get_horizon(value::CostCoefficientInternal) = value.horizon
"""Get CostCoefficientInternal internal."""
get_internal(value::CostCoefficientInternal) = value.internal

"""Set CostCoefficientInternal label."""
set_label!(value::CostCoefficientInternal, val::String) = value.label = val
"""Set CostCoefficientInternal resolution."""
set_resolution!(value::CostCoefficientInternal, val::Dates.Period) = value.resolution = val
"""Set CostCoefficientInternal initial_time."""
set_initial_time!(value::CostCoefficientInternal, val::Dates.DateTime) = value.initial_time = val
"""Set CostCoefficientInternal break_points."""
set_break_points!(value::CostCoefficientInternal, val::Int64) = value.break_points = val
"""Set CostCoefficientInternal time_series_uuid."""
set_time_series_uuid!(value::CostCoefficientInternal, val::UUIDs.UUID) = value.time_series_uuid = val
"""Set CostCoefficientInternal horizon."""
set_horizon!(value::CostCoefficientInternal, val::Int) = value.horizon = val
"""Set CostCoefficientInternal internal."""
set_internal!(value::CostCoefficientInternal, val::InfrastructureSystemsInternal) = value.internal = val
