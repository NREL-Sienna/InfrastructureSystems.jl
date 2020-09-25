#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Scenarios <: Forecast
        label::String
        initial_time_stamp::Dates.DateTime
        horizon::Int
        resolution::Dates.Period
        scenario_count::Int64
        data::SortedDict{Dates.DateTime, Array}
        scaling_factor_multiplier::Union{Nothing, Function}
        internal::InfrastructureSystemsInternal
    end

A Discrete Scenario Based time series for a particular data field in a Component.

# Arguments
- `label::String`: user-defined label
- `initial_time_stamp::Dates.DateTime`: first timestamp in forecast
- `horizon::Int`: length of this time series
- `resolution::Dates.Period`: forecast resolution
- `scenario_count::Int64`: Number of scenarios
- `data::SortedDict{Dates.DateTime, Array}`: timestamp - scalingfactor
- `scaling_factor_multiplier::Union{Nothing, Function}`: Applicable when the time series data are scaling factors. Called on the associated component to convert the values.
- `internal::InfrastructureSystemsInternal`
"""
mutable struct Scenarios <: Forecast
    "user-defined label"
    label::String
    "first timestamp in forecast"
    initial_time_stamp::Dates.DateTime
    "length of this time series"
    horizon::Int
    "forecast resolution"
    resolution::Dates.Period
    "Number of scenarios"
    scenario_count::Int64
    "timestamp - scalingfactor"
    data::SortedDict{Dates.DateTime, Array}
    "Applicable when the time series data are scaling factors. Called on the associated component to convert the values."
    scaling_factor_multiplier::Union{Nothing, Function}
    internal::InfrastructureSystemsInternal
end

function Scenarios(label, initial_time_stamp, horizon, resolution, scenario_count, data, scaling_factor_multiplier=nothing, )
    Scenarios(label, initial_time_stamp, horizon, resolution, scenario_count, data, scaling_factor_multiplier, InfrastructureSystemsInternal(), )
end

function Scenarios(; label, initial_time_stamp, horizon, resolution, scenario_count, data, scaling_factor_multiplier=nothing, internal=InfrastructureSystemsInternal(), )
    Scenarios(label, initial_time_stamp, horizon, resolution, scenario_count, data, scaling_factor_multiplier, internal, )
end

"""Get [`Scenarios`](@ref) `label`."""
get_label(value::Scenarios) = value.label
"""Get [`Scenarios`](@ref) `initial_time_stamp`."""
get_initial_time_stamp(value::Scenarios) = value.initial_time_stamp
"""Get [`Scenarios`](@ref) `horizon`."""
get_horizon(value::Scenarios) = value.horizon
"""Get [`Scenarios`](@ref) `resolution`."""
get_resolution(value::Scenarios) = value.resolution
"""Get [`Scenarios`](@ref) `scenario_count`."""
get_scenario_count(value::Scenarios) = value.scenario_count
"""Get [`Scenarios`](@ref) `data`."""
get_data(value::Scenarios) = value.data
"""Get [`Scenarios`](@ref) `scaling_factor_multiplier`."""
get_scaling_factor_multiplier(value::Scenarios) = value.scaling_factor_multiplier
"""Get [`Scenarios`](@ref) `internal`."""
get_internal(value::Scenarios) = value.internal

"""Set [`Scenarios`](@ref) `label`."""
set_label!(value::Scenarios, val) = value.label = val
"""Set [`Scenarios`](@ref) `initial_time_stamp`."""
set_initial_time_stamp!(value::Scenarios, val) = value.initial_time_stamp = val
"""Set [`Scenarios`](@ref) `horizon`."""
set_horizon!(value::Scenarios, val) = value.horizon = val
"""Set [`Scenarios`](@ref) `resolution`."""
set_resolution!(value::Scenarios, val) = value.resolution = val
"""Set [`Scenarios`](@ref) `scenario_count`."""
set_scenario_count!(value::Scenarios, val) = value.scenario_count = val
"""Set [`Scenarios`](@ref) `data`."""
set_data!(value::Scenarios, val) = value.data = val
"""Set [`Scenarios`](@ref) `scaling_factor_multiplier`."""
set_scaling_factor_multiplier!(value::Scenarios, val) = value.scaling_factor_multiplier = val
"""Set [`Scenarios`](@ref) `internal`."""
set_internal!(value::Scenarios, val) = value.internal = val

