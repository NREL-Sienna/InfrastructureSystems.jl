#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct ScenarioBasedInternal <: ForecastInternal
        label::String
        resolution::Dates.Period
        initial_time::Dates.DateTime
        scenario_count::Int64
        time_series_uuid::UUIDs.UUID
        horizon::Int
        internal::InfrastructureSystemsInternal
    end

A Discrete Scenario Based forecast for a particular data field in a Component.

# Arguments
- `label::String`: label of component parameter forecasted
- `resolution::Dates.Period`
- `initial_time::Dates.DateTime`: forecast availability time
- `scenario_count::Int64`: Number of scenarios
- `time_series_uuid::UUIDs.UUID`: reference to time series data; timestamp - scalingfactor
- `horizon::Int`: length of this forecast
- `internal::InfrastructureSystemsInternal`
"""
mutable struct ScenarioBasedInternal <: ForecastInternal
    "label of component parameter forecasted"
    label::String
    resolution::Dates.Period
    "forecast availability time"
    initial_time::Dates.DateTime
    "Number of scenarios"
    scenario_count::Int64
    "reference to time series data; timestamp - scalingfactor"
    time_series_uuid::UUIDs.UUID
    "length of this forecast"
    horizon::Int
    internal::InfrastructureSystemsInternal
end

function ScenarioBasedInternal(label, resolution, initial_time, scenario_count, time_series_uuid, horizon, )
    ScenarioBasedInternal(label, resolution, initial_time, scenario_count, time_series_uuid, horizon, InfrastructureSystemsInternal(), )
end

function ScenarioBasedInternal(; label, resolution, initial_time, scenario_count, time_series_uuid, horizon, internal=InfrastructureSystemsInternal(), )
    ScenarioBasedInternal(label, resolution, initial_time, scenario_count, time_series_uuid, horizon, internal, )
end

"""Get [`ScenarioBasedInternal`](@ref) `label`."""
get_label(value::ScenarioBasedInternal) = value.label
"""Get [`ScenarioBasedInternal`](@ref) `resolution`."""
get_resolution(value::ScenarioBasedInternal) = value.resolution
"""Get [`ScenarioBasedInternal`](@ref) `initial_time`."""
get_initial_time(value::ScenarioBasedInternal) = value.initial_time
"""Get [`ScenarioBasedInternal`](@ref) `scenario_count`."""
get_scenario_count(value::ScenarioBasedInternal) = value.scenario_count
"""Get [`ScenarioBasedInternal`](@ref) `time_series_uuid`."""
get_time_series_uuid(value::ScenarioBasedInternal) = value.time_series_uuid
"""Get [`ScenarioBasedInternal`](@ref) `horizon`."""
get_horizon(value::ScenarioBasedInternal) = value.horizon
"""Get [`ScenarioBasedInternal`](@ref) `internal`."""
get_internal(value::ScenarioBasedInternal) = value.internal

"""Set [`ScenarioBasedInternal`](@ref) `label`."""
set_label!(value::ScenarioBasedInternal, val) = value.label = val
"""Set [`ScenarioBasedInternal`](@ref) `resolution`."""
set_resolution!(value::ScenarioBasedInternal, val) = value.resolution = val
"""Set [`ScenarioBasedInternal`](@ref) `initial_time`."""
set_initial_time!(value::ScenarioBasedInternal, val) = value.initial_time = val
"""Set [`ScenarioBasedInternal`](@ref) `scenario_count`."""
set_scenario_count!(value::ScenarioBasedInternal, val) = value.scenario_count = val
"""Set [`ScenarioBasedInternal`](@ref) `time_series_uuid`."""
set_time_series_uuid!(value::ScenarioBasedInternal, val) = value.time_series_uuid = val
"""Set [`ScenarioBasedInternal`](@ref) `horizon`."""
set_horizon!(value::ScenarioBasedInternal, val) = value.horizon = val
"""Set [`ScenarioBasedInternal`](@ref) `internal`."""
set_internal!(value::ScenarioBasedInternal, val) = value.internal = val
