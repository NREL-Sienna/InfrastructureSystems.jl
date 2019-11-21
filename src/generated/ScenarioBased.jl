#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct ScenarioBased <: Forecast
        label::String
        scenario_count::Int64
        data::TimeSeries.TimeArray
        ext::Union{Nothing, Dict{String, Any}}
    end

A Discrete Scenario Based forecast for a particular data field in a Component.

# Arguments
- `label::String`: label of component parameter forecasted
- `scenario_count::Int64`: Number of scenarios
- `data::TimeSeries.TimeArray`: timestamp - scalingfactor
- `ext::Union{Nothing, Dict{String, Any}}`
"""
mutable struct ScenarioBased <: Forecast
    "label of component parameter forecasted"
    label::String
    "Number of scenarios"
    scenario_count::Int64
    "timestamp - scalingfactor"
    data::TimeSeries.TimeArray
    ext::Union{Nothing, Dict{String, Any}}
end



function ScenarioBased(; label, scenario_count, data, ext, )
    ScenarioBased(label, scenario_count, data, ext, )
end


"""Get ScenarioBased label."""
get_label(value::ScenarioBased) = value.label
"""Get ScenarioBased scenario_count."""
get_scenario_count(value::ScenarioBased) = value.scenario_count
"""Get ScenarioBased data."""
get_data(value::ScenarioBased) = value.data
"""Get ScenarioBased ext."""
get_ext(value::ScenarioBased) = value.ext
