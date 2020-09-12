#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct ScenarioBasedMetadata <: TimeSeriesMetadata
        label::String
        resolution::Dates.Period
        initial_time::Dates.DateTime
        scenario_count::Int64
        time_series_uuid::UUIDs.UUID
        horizon::Int
        scaling_factor_multiplier::Union{Nothing, Function}
        internal::InfrastructureSystemsInternal
    end

A Discrete Scenario Based time series for a particular data field in a Component.

# Arguments
- `label::String`: user-defined label
- `resolution::Dates.Period`
- `initial_time::Dates.DateTime`: time series availability time
- `scenario_count::Int64`: Number of scenarios
- `time_series_uuid::UUIDs.UUID`: reference to time series data
- `horizon::Int`: length of this time series
- `scaling_factor_multiplier::Union{Nothing, Function}`: Applicable when the time series data are scaling factors. Called on the associated component to convert the values.
- `internal::InfrastructureSystemsInternal`
"""
mutable struct ScenarioBasedMetadata <: TimeSeriesMetadata
    "user-defined label"
    label::String
    resolution::Dates.Period
    "time series availability time"
    initial_time::Dates.DateTime
    "Number of scenarios"
    scenario_count::Int64
    "reference to time series data"
    time_series_uuid::UUIDs.UUID
    "length of this time series"
    horizon::Int
    "Applicable when the time series data are scaling factors. Called on the associated component to convert the values."
    scaling_factor_multiplier::Union{Nothing, Function}
    internal::InfrastructureSystemsInternal
end

function ScenarioBasedMetadata(label, resolution, initial_time, scenario_count, time_series_uuid, horizon, scaling_factor_multiplier=nothing, )
    ScenarioBasedMetadata(label, resolution, initial_time, scenario_count, time_series_uuid, horizon, scaling_factor_multiplier, InfrastructureSystemsInternal(), )
end

function ScenarioBasedMetadata(; label, resolution, initial_time, scenario_count, time_series_uuid, horizon, scaling_factor_multiplier=nothing, internal=InfrastructureSystemsInternal(), )
    ScenarioBasedMetadata(label, resolution, initial_time, scenario_count, time_series_uuid, horizon, scaling_factor_multiplier, internal, )
end

"""Get [`ScenarioBasedMetadata`](@ref) `label`."""
get_label(value::ScenarioBasedMetadata) = value.label
"""Get [`ScenarioBasedMetadata`](@ref) `resolution`."""
get_resolution(value::ScenarioBasedMetadata) = value.resolution
"""Get [`ScenarioBasedMetadata`](@ref) `initial_time`."""
get_initial_time(value::ScenarioBasedMetadata) = value.initial_time
"""Get [`ScenarioBasedMetadata`](@ref) `scenario_count`."""
get_scenario_count(value::ScenarioBasedMetadata) = value.scenario_count
"""Get [`ScenarioBasedMetadata`](@ref) `time_series_uuid`."""
get_time_series_uuid(value::ScenarioBasedMetadata) = value.time_series_uuid
"""Get [`ScenarioBasedMetadata`](@ref) `horizon`."""
get_horizon(value::ScenarioBasedMetadata) = value.horizon
"""Get [`ScenarioBasedMetadata`](@ref) `scaling_factor_multiplier`."""
get_scaling_factor_multiplier(value::ScenarioBasedMetadata) = value.scaling_factor_multiplier
"""Get [`ScenarioBasedMetadata`](@ref) `internal`."""
get_internal(value::ScenarioBasedMetadata) = value.internal

"""Set [`ScenarioBasedMetadata`](@ref) `label`."""
set_label!(value::ScenarioBasedMetadata, val) = value.label = val
"""Set [`ScenarioBasedMetadata`](@ref) `resolution`."""
set_resolution!(value::ScenarioBasedMetadata, val) = value.resolution = val
"""Set [`ScenarioBasedMetadata`](@ref) `initial_time`."""
set_initial_time!(value::ScenarioBasedMetadata, val) = value.initial_time = val
"""Set [`ScenarioBasedMetadata`](@ref) `scenario_count`."""
set_scenario_count!(value::ScenarioBasedMetadata, val) = value.scenario_count = val
"""Set [`ScenarioBasedMetadata`](@ref) `time_series_uuid`."""
set_time_series_uuid!(value::ScenarioBasedMetadata, val) = value.time_series_uuid = val
"""Set [`ScenarioBasedMetadata`](@ref) `horizon`."""
set_horizon!(value::ScenarioBasedMetadata, val) = value.horizon = val
"""Set [`ScenarioBasedMetadata`](@ref) `scaling_factor_multiplier`."""
set_scaling_factor_multiplier!(value::ScenarioBasedMetadata, val) = value.scaling_factor_multiplier = val
"""Set [`ScenarioBasedMetadata`](@ref) `internal`."""
set_internal!(value::ScenarioBasedMetadata, val) = value.internal = val

