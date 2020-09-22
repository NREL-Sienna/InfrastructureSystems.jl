#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Scenarios <: Forecast
        label::String
        scenario_count::Int64
        data::Dict{Dates.DateTime, TimeSeries.TimeArray}
        scaling_factor_multiplier::Union{Nothing, Function}
    end

A Discrete Scenario Based time series for a particular data field in a Component.

# Arguments
- `label::String`: user-defined label
- `scenario_count::Int64`: Number of scenarios
- `data::Dict{Dates.DateTime, TimeSeries.TimeArray}`: timestamp - scalingfactor
- `scaling_factor_multiplier::Union{Nothing, Function}`: Applicable when the time series data are scaling factors. Called on the associated component to convert the values.
"""
mutable struct Scenarios <: Forecast
    "user-defined label"
    label::String
    "Number of scenarios"
    scenario_count::Int64
    "timestamp - scalingfactor"
    data::Dict{Dates.DateTime, TimeSeries.TimeArray}
    "Applicable when the time series data are scaling factors. Called on the associated component to convert the values."
    scaling_factor_multiplier::Union{Nothing, Function}
end


function Scenarios(; label, scenario_count, data, scaling_factor_multiplier=nothing, )
    Scenarios(label, scenario_count, data, scaling_factor_multiplier, )
end

"""Get [`Scenarios`](@ref) `label`."""
get_label(value::Scenarios) = value.label
"""Get [`Scenarios`](@ref) `scenario_count`."""
get_scenario_count(value::Scenarios) = value.scenario_count
"""Get [`Scenarios`](@ref) `data`."""
get_data(value::Scenarios) = value.data
"""Get [`Scenarios`](@ref) `scaling_factor_multiplier`."""
get_scaling_factor_multiplier(value::Scenarios) = value.scaling_factor_multiplier

"""Set [`Scenarios`](@ref) `label`."""
set_label!(value::Scenarios, val) = value.label = val
"""Set [`Scenarios`](@ref) `scenario_count`."""
set_scenario_count!(value::Scenarios, val) = value.scenario_count = val
"""Set [`Scenarios`](@ref) `data`."""
set_data!(value::Scenarios, val) = value.data = val
"""Set [`Scenarios`](@ref) `scaling_factor_multiplier`."""
set_scaling_factor_multiplier!(value::Scenarios, val) = value.scaling_factor_multiplier = val

