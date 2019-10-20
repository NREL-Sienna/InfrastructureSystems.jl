#=
This file is auto-generated. Do not edit.
=#

"""A deterministic forecast for a particular data field in a Component."""
mutable struct DeterministicInternal <: ForecastInternal
    label::String  # label of component parameter forecasted
    resolution::Dates.Period
    initial_time::Dates.DateTime  # forecast availability time
    time_series_uuid::UUIDs.UUID  # reference to time series data; timestamp - scalingfactor
    horizon::Int  # length of this forecast
    internal::InfrastructureSystemsInternal
end

function DeterministicInternal(label, resolution, initial_time, time_series_uuid, horizon, )
    DeterministicInternal(label, resolution, initial_time, time_series_uuid, horizon, InfrastructureSystemsInternal())
end

function DeterministicInternal(; label, resolution, initial_time, time_series_uuid, horizon, )
    DeterministicInternal(label, resolution, initial_time, time_series_uuid, horizon, )
end


"""Get DeterministicInternal label."""
get_label(value::DeterministicInternal) = value.label
"""Get DeterministicInternal resolution."""
get_resolution(value::DeterministicInternal) = value.resolution
"""Get DeterministicInternal initial_time."""
get_initial_time(value::DeterministicInternal) = value.initial_time
"""Get DeterministicInternal time_series_uuid."""
get_time_series_uuid(value::DeterministicInternal) = value.time_series_uuid
"""Get DeterministicInternal horizon."""
get_horizon(value::DeterministicInternal) = value.horizon
"""Get DeterministicInternal internal."""
get_internal(value::DeterministicInternal) = value.internal
