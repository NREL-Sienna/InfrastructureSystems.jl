#=
This file is auto-generated. Do not edit.
=#

#! format: off

"""
    mutable struct ScenariosMetadata <: ForecastMetadata
        name::String
        resolution::Dates.Period
        initial_timestamp::Dates.DateTime
        interval::Dates.Period
        scenario_count::Int64
        count::Int
        time_series_uuid::UUIDs.UUID
        horizon::Int
        scaling_factor_multiplier::Union{Nothing, Function}
        internal::InfrastructureSystemsInternal
    end

A Discrete Scenario Based time series for a particular data field in a Component.

# Arguments
- `name::String`: user-defined name
- `resolution::Dates.Period`
- `initial_timestamp::Dates.DateTime`: time series availability time
- `interval::Dates.Period`: time step between forecast windows
- `scenario_count::Int64`: Number of scenarios
- `count::Int`: number of forecast windows
- `time_series_uuid::UUIDs.UUID`: reference to time series data
- `horizon::Int`: length of this time series
- `scaling_factor_multiplier::Union{Nothing, Function}`: Applicable when the time series data are scaling factors. Called on the associated component to convert the values.
- `internal::InfrastructureSystemsInternal`
"""
mutable struct ScenariosMetadata <: ForecastMetadata
    "user-defined name"
    name::String
    resolution::Dates.Period
    "time series availability time"
    initial_timestamp::Dates.DateTime
    "time step between forecast windows"
    interval::Dates.Period
    "Number of scenarios"
    scenario_count::Int64
    "number of forecast windows"
    count::Int
    "reference to time series data"
    time_series_uuid::UUIDs.UUID
    "length of this time series"
    horizon::Int
    "Applicable when the time series data are scaling factors. Called on the associated component to convert the values."
    scaling_factor_multiplier::Union{Nothing, Function}
    internal::InfrastructureSystemsInternal
end

function ScenariosMetadata(name, resolution, initial_timestamp, interval, scenario_count, count, time_series_uuid, horizon, scaling_factor_multiplier=nothing, )
    ScenariosMetadata(name, resolution, initial_timestamp, interval, scenario_count, count, time_series_uuid, horizon, scaling_factor_multiplier, InfrastructureSystemsInternal(), )
end

function ScenariosMetadata(; name, resolution, initial_timestamp, interval, scenario_count, count, time_series_uuid, horizon, scaling_factor_multiplier=nothing, internal=InfrastructureSystemsInternal(), )
    ScenariosMetadata(name, resolution, initial_timestamp, interval, scenario_count, count, time_series_uuid, horizon, scaling_factor_multiplier, internal, )
end

"""Get [`ScenariosMetadata`](@ref) `name`."""
get_name(value::ScenariosMetadata) = value.name
"""Get [`ScenariosMetadata`](@ref) `resolution`."""
get_resolution(value::ScenariosMetadata) = value.resolution
"""Get [`ScenariosMetadata`](@ref) `initial_timestamp`."""
get_initial_timestamp(value::ScenariosMetadata) = value.initial_timestamp
"""Get [`ScenariosMetadata`](@ref) `interval`."""
get_interval(value::ScenariosMetadata) = value.interval
"""Get [`ScenariosMetadata`](@ref) `scenario_count`."""
get_scenario_count(value::ScenariosMetadata) = value.scenario_count
"""Get [`ScenariosMetadata`](@ref) `count`."""
get_count(value::ScenariosMetadata) = value.count
"""Get [`ScenariosMetadata`](@ref) `time_series_uuid`."""
get_time_series_uuid(value::ScenariosMetadata) = value.time_series_uuid
"""Get [`ScenariosMetadata`](@ref) `horizon`."""
get_horizon(value::ScenariosMetadata) = value.horizon
"""Get [`ScenariosMetadata`](@ref) `scaling_factor_multiplier`."""
get_scaling_factor_multiplier(value::ScenariosMetadata) = value.scaling_factor_multiplier
"""Get [`ScenariosMetadata`](@ref) `internal`."""
get_internal(value::ScenariosMetadata) = value.internal

"""Set [`ScenariosMetadata`](@ref) `name`."""
set_name!(value::ScenariosMetadata, val) = value.name = val
"""Set [`ScenariosMetadata`](@ref) `resolution`."""
set_resolution!(value::ScenariosMetadata, val) = value.resolution = val
"""Set [`ScenariosMetadata`](@ref) `initial_timestamp`."""
set_initial_timestamp!(value::ScenariosMetadata, val) = value.initial_timestamp = val
"""Set [`ScenariosMetadata`](@ref) `interval`."""
set_interval!(value::ScenariosMetadata, val) = value.interval = val
"""Set [`ScenariosMetadata`](@ref) `scenario_count`."""
set_scenario_count!(value::ScenariosMetadata, val) = value.scenario_count = val
"""Set [`ScenariosMetadata`](@ref) `count`."""
set_count!(value::ScenariosMetadata, val) = value.count = val
"""Set [`ScenariosMetadata`](@ref) `time_series_uuid`."""
set_time_series_uuid!(value::ScenariosMetadata, val) = value.time_series_uuid = val
"""Set [`ScenariosMetadata`](@ref) `horizon`."""
set_horizon!(value::ScenariosMetadata, val) = value.horizon = val
"""Set [`ScenariosMetadata`](@ref) `scaling_factor_multiplier`."""
set_scaling_factor_multiplier!(value::ScenariosMetadata, val) = value.scaling_factor_multiplier = val
"""Set [`ScenariosMetadata`](@ref) `internal`."""
set_internal!(value::ScenariosMetadata, val) = value.internal = val
