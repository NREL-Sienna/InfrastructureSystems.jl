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

function DeterministicInternal(; label, resolution, initial_time, time_series_uuid, horizon, internal=InfrastructureSystemsInternal(), )
    DeterministicInternal(label, resolution, initial_time, time_series_uuid, horizon, internal, )
end

"""Get [`DeterministicInternal`](@ref) `label`."""
get_label(value::DeterministicInternal) = value.label
"""Get [`DeterministicInternal`](@ref) `resolution`."""
get_resolution(value::DeterministicInternal) = value.resolution
"""Get [`DeterministicInternal`](@ref) `initial_time`."""
get_initial_time(value::DeterministicInternal) = value.initial_time
"""Get [`DeterministicInternal`](@ref) `time_series_uuid`."""
get_time_series_uuid(value::DeterministicInternal) = value.time_series_uuid
"""Get [`DeterministicInternal`](@ref) `horizon`."""
get_horizon(value::DeterministicInternal) = value.horizon
"""Get [`DeterministicInternal`](@ref) `internal`."""
get_internal(value::DeterministicInternal) = value.internal

"""Set [`DeterministicInternal`](@ref) `label`."""
set_label!(value::DeterministicInternal, val) = value.label = val
"""Set [`DeterministicInternal`](@ref) `resolution`."""
set_resolution!(value::DeterministicInternal, val) = value.resolution = val
"""Set [`DeterministicInternal`](@ref) `initial_time`."""
set_initial_time!(value::DeterministicInternal, val) = value.initial_time = val
"""Set [`DeterministicInternal`](@ref) `time_series_uuid`."""
set_time_series_uuid!(value::DeterministicInternal, val) = value.time_series_uuid = val
"""Set [`DeterministicInternal`](@ref) `horizon`."""
set_horizon!(value::DeterministicInternal, val) = value.horizon = val
"""Set [`DeterministicInternal`](@ref) `internal`."""
set_internal!(value::DeterministicInternal, val) = value.internal = val
