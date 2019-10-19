#=
This file is auto-generated. Do not edit.
=#

"""A Discrete Scenario Based forecast for a particular data field in a Component."""
mutable struct ScenarioBasedInternal <: ForecastInternal
    label::String  # label of component parameter forecasted
    resolution::Dates.Period
    initial_time::Dates.DateTime  # forecast availability time
    scenario_count::Int64  # Number of scenarios
    time_series_uuid::UUIDs.UUID  # reference to time series data; timestamp - scalingfactor
    horizon::Int  # length of this forecast
    internal::InfrastructureSystemsInternal
end

function ScenarioBasedInternal(label, resolution, initial_time, scenario_count, time_series_uuid, horizon, )
    ScenarioBasedInternal(label, resolution, initial_time, scenario_count, time_series_uuid, horizon, InfrastructureSystemsInternal())
end

function ScenarioBasedInternal(; label, resolution, initial_time, scenario_count, time_series_uuid, horizon, )
    ScenarioBasedInternal(label, resolution, initial_time, scenario_count, time_series_uuid, horizon, )
end


"""Get ScenarioBasedInternal label."""
get_label(value::ScenarioBasedInternal) = value.label
"""Get ScenarioBasedInternal resolution."""
get_resolution(value::ScenarioBasedInternal) = value.resolution
"""Get ScenarioBasedInternal initial_time."""
get_initial_time(value::ScenarioBasedInternal) = value.initial_time
"""Get ScenarioBasedInternal scenario_count."""
get_scenario_count(value::ScenarioBasedInternal) = value.scenario_count
"""Get ScenarioBasedInternal time_series_uuid."""
get_time_series_uuid(value::ScenarioBasedInternal) = value.time_series_uuid
"""Get ScenarioBasedInternal horizon."""
get_horizon(value::ScenarioBasedInternal) = value.horizon
"""Get ScenarioBasedInternal internal."""
get_internal(value::ScenarioBasedInternal) = value.internal
