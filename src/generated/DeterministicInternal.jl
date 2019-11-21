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
    DeterministicInternal(label, resolution, initial_time, time_series_uuid, horizon, InfrastructureSystemsInternal())
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
