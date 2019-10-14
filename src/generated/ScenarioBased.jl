#=
This file is auto-generated. Do not edit.
=#

"""A Discrete Scenario Based forecast for a particular data field in a Component."""
mutable struct ScenarioBased <: Forecast
    label::String  # label of component parameter forecasted
    scenario_count::Int64  # Number of scenarios
    data::TimeSeries.TimeArray  # timestamp - scalingfactor
end



function ScenarioBased(; label, scenario_count, data, )
    ScenarioBased(label, scenario_count, data, )
end


"""Get ScenarioBased label."""
get_label(value::ScenarioBased) = value.label
"""Get ScenarioBased scenario_count."""
get_scenario_count(value::ScenarioBased) = value.scenario_count
"""Get ScenarioBased data."""
get_data(value::ScenarioBased) = value.data
