#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct DeterministicInternal <: ForecastInternal
        label::String
        resolution::Dates.Period
        initial_time::Dates.DateTime
        time_series_uuid::UUIDs.UUID
        horizon::Int
        internal::InfrastructureSystemsInternal
    end

A deterministic forecast for a particular data field in a Component.

# Arguments
- `label::String`: label of component parameter forecasted
- `resolution::Dates.Period`
- `initial_time::Dates.DateTime`: forecast availability time
- `time_series_uuid::UUIDs.UUID`: reference to time series data; timestamp - scalingfactor
- `horizon::Int`: length of this forecast
- `internal::InfrastructureSystemsInternal`
"""
mutable struct DeterministicInternal <: ForecastInternal
    "label of component parameter forecasted"
    label::String
    resolution::Dates.Period
    "forecast availability time"
    initial_time::Dates.DateTime
    "reference to time series data; timestamp - scalingfactor"
    time_series_uuid::UUIDs.UUID
    "length of this forecast"
    horizon::Int
    internal::InfrastructureSystemsInternal
end

function DeterministicInternal(label, resolution, initial_time, time_series_uuid, horizon, )
    DeterministicInternal(label, resolution, initial_time, time_series_uuid, horizon, InfrastructureSystemsInternal(), )
end

function DeterministicInternal(; label, resolution, initial_time, time_series_uuid, horizon, )
    DeterministicInternal(label, resolution, initial_time, time_series_uuid, horizon, )
end

"""Get DeterministicInternal label."""
get_label(value::DeterministicInternal) = value.label
"""Get DeterministicInternal resolution."""
get_resolution(value::DeterministicInternal) = value.resolution
"""Get DeterministicInternal initial_time."""
get_initial_time(value::DeterministicInternal) = value.initial_time
"""Get DeterministicInternal time_series_uuid."""
get_time_series_uuid(value::DeterministicInternal) = value.time_series_uuid
"""Get DeterministicInternal horizon."""
get_horizon(value::DeterministicInternal) = value.horizon
"""Get DeterministicInternal internal."""
get_internal(value::DeterministicInternal) = value.internal

"""Set DeterministicInternal label."""
set_label!(value::DeterministicInternal, val::String) = value.label = val
"""Set DeterministicInternal resolution."""
set_resolution!(value::DeterministicInternal, val::Dates.Period) = value.resolution = val
"""Set DeterministicInternal initial_time."""
set_initial_time!(value::DeterministicInternal, val::Dates.DateTime) = value.initial_time = val
"""Set DeterministicInternal time_series_uuid."""
set_time_series_uuid!(value::DeterministicInternal, val::UUIDs.UUID) = value.time_series_uuid = val
"""Set DeterministicInternal horizon."""
set_horizon!(value::DeterministicInternal, val::Int) = value.horizon = val
"""Set DeterministicInternal internal."""
set_internal!(value::DeterministicInternal, val::InfrastructureSystemsInternal) = value.internal = val
