#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct ScenarioBased <: TimeSeriesData
        label::String
        scenario_count::Int64
        data::TimeSeries.TimeArray
    end

A Discrete Scenario Based time series for a particular data field in a Component.

# Arguments
- `label::String`: user-defined label
- `scenario_count::Int64`: Number of scenarios
- `data::TimeSeries.TimeArray`: timestamp - scalingfactor
"""
mutable struct ScenarioBased <: TimeSeriesData
    "user-defined label"
    label::String
    "Number of scenarios"
    scenario_count::Int64
    "timestamp - scalingfactor"
    data::TimeSeries.TimeArray
end


function ScenarioBased(; label, scenario_count, data, )
    ScenarioBased(label, scenario_count, data, )
end

"""Get [`ScenarioBased`](@ref) `label`."""
get_label(value::ScenarioBased) = value.label
"""Get [`ScenarioBased`](@ref) `scenario_count`."""
get_scenario_count(value::ScenarioBased) = value.scenario_count
"""Get [`ScenarioBased`](@ref) `data`."""
get_data(value::ScenarioBased) = value.data

"""Set [`ScenarioBased`](@ref) `label`."""
set_label!(value::ScenarioBased, val) = value.label = val
"""Set [`ScenarioBased`](@ref) `scenario_count`."""
set_scenario_count!(value::ScenarioBased, val) = value.scenario_count = val
"""Set [`ScenarioBased`](@ref) `data`."""
set_data!(value::ScenarioBased, val) = value.data = val

