#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct ScenarioBased <: TimeSeriesData
        label::String
        scenario_count::Int64
        data::TimeSeries.TimeArray
        scaling_factor_multiplier::Union{Nothing, Function}
    end

A Discrete Scenario Based time series for a particular data field in a Component.

# Arguments
- `label::String`: user-defined label
- `scenario_count::Int64`: Number of scenarios
- `data::TimeSeries.TimeArray`: timestamp - scalingfactor
- `scaling_factor_multiplier::Union{Nothing, Function}`: Applicable when the time series data are scaling factors. Called on the associated component to convert the values.
"""
mutable struct ScenarioBased <: TimeSeriesData
    "user-defined label"
    label::String
    "Number of scenarios"
    scenario_count::Int64
    "timestamp - scalingfactor"
    data::TimeSeries.TimeArray
    "Applicable when the time series data are scaling factors. Called on the associated component to convert the values."
    scaling_factor_multiplier::Union{Nothing, Function}
end


function ScenarioBased(; label, scenario_count, data, scaling_factor_multiplier=nothing, )
    ScenarioBased(label, scenario_count, data, scaling_factor_multiplier, )
end

"""Get [`ScenarioBased`](@ref) `label`."""
get_label(value::ScenarioBased) = value.label
"""Get [`ScenarioBased`](@ref) `scenario_count`."""
get_scenario_count(value::ScenarioBased) = value.scenario_count
"""Get [`ScenarioBased`](@ref) `data`."""
get_data(value::ScenarioBased) = value.data
"""Get [`ScenarioBased`](@ref) `scaling_factor_multiplier`."""
get_scaling_factor_multiplier(value::ScenarioBased) = value.scaling_factor_multiplier

"""Set [`ScenarioBased`](@ref) `label`."""
set_label!(value::ScenarioBased, val) = value.label = val
"""Set [`ScenarioBased`](@ref) `scenario_count`."""
set_scenario_count!(value::ScenarioBased, val) = value.scenario_count = val
"""Set [`ScenarioBased`](@ref) `data`."""
set_data!(value::ScenarioBased, val) = value.data = val
"""Set [`ScenarioBased`](@ref) `scaling_factor_multiplier`."""
set_scaling_factor_multiplier!(value::ScenarioBased, val) = value.scaling_factor_multiplier = val

