#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Scenarios <: Forecast
        name::String
        resolution::Dates.Period
        scenario_count::Int64
        data::SortedDict{Dates.DateTime, Array}
        scaling_factor_multiplier::Union{Nothing, Function}
        internal::InfrastructureSystemsInternal
    end

A Discrete Scenario Based time series for a particular data field in a Component.

# Arguments
- `name::String`: user-defined name
- `resolution::Dates.Period`: forecast resolution
- `scenario_count::Int64`: Number of scenarios
- `data::SortedDict{Dates.DateTime, Array}`: timestamp - scalingfactor
- `scaling_factor_multiplier::Union{Nothing, Function}`: Applicable when the time series data are scaling factors. Called on the associated component to convert the values.
- `internal::InfrastructureSystemsInternal`
"""
mutable struct Scenarios <: Forecast
    "user-defined name"
    name::String
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

function Scenarios(name, resolution, scenario_count, data, scaling_factor_multiplier=nothing, )
    Scenarios(name, resolution, scenario_count, data, scaling_factor_multiplier, InfrastructureSystemsInternal(), )
end

function Scenarios(; name, resolution, scenario_count, data, scaling_factor_multiplier=nothing, internal=InfrastructureSystemsInternal(), )
    Scenarios(name, resolution, scenario_count, data, scaling_factor_multiplier, internal, )
end

"""Get [`Scenarios`](@ref) `name`."""
get_name(value::Scenarios) = value.name
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

"""Set [`Scenarios`](@ref) `name`."""
set_name!(value::Scenarios, val) = value.name = val
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

