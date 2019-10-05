#=
This file is auto-generated. Do not edit.
=#

"""A Probabilistic forecast for a particular data field in a Component."""
mutable struct ProbabilisticInternal <: ForecastInternal
    label::String  # label of component parameter forecasted
    resolution::Dates.Period
    initial_time::Dates.DateTime  # forecast availability time
    percentiles::Vector{Float64}  # Percentiles for the probabilistic forecast
    time_series_uuid::UUIDs.UUID  # reference to time series data; timestamp - scalingfactor
    horizon::Int  # length of this forecast
    internal::InfrastructureSystemsInternal
end

function ProbabilisticInternal(label, resolution, initial_time, percentiles, time_series_uuid, horizon, )
    ProbabilisticInternal(label, resolution, initial_time, percentiles, time_series_uuid, horizon, InfrastructureSystemsInternal())
end

function ProbabilisticInternal(; label, resolution, initial_time, percentiles, time_series_uuid, horizon, )
    ProbabilisticInternal(label, resolution, initial_time, percentiles, time_series_uuid, horizon, )
end


"""Get ProbabilisticInternal label."""
get_label(value::ProbabilisticInternal) = value.label
"""Get ProbabilisticInternal resolution."""
get_resolution(value::ProbabilisticInternal) = value.resolution
"""Get ProbabilisticInternal initial_time."""
get_initial_time(value::ProbabilisticInternal) = value.initial_time
"""Get ProbabilisticInternal percentiles."""
get_percentiles(value::ProbabilisticInternal) = value.percentiles
"""Get ProbabilisticInternal time_series_uuid."""
get_time_series_uuid(value::ProbabilisticInternal) = value.time_series_uuid
"""Get ProbabilisticInternal horizon."""
get_horizon(value::ProbabilisticInternal) = value.horizon
"""Get ProbabilisticInternal internal."""
get_internal(value::ProbabilisticInternal) = value.internal
