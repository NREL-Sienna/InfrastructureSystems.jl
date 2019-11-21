#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct ProbabilisticInternal <: ForecastInternal
        label::String
        resolution::Dates.Period
        initial_time::Dates.DateTime
        percentiles::Vector{Float64}
        time_series_uuid::UUIDs.UUID
        horizon::Int
        internal::InfrastructureSystemsInternal
    end

A Probabilistic forecast for a particular data field in a Component.

# Arguments
- `label::String`: label of component parameter forecasted
- `resolution::Dates.Period`
- `initial_time::Dates.DateTime`: forecast availability time
- `percentiles::Vector{Float64}`: Percentiles for the probabilistic forecast
- `time_series_uuid::UUIDs.UUID`: reference to time series data; timestamp - scalingfactor
- `horizon::Int`: length of this forecast
- `internal::InfrastructureSystemsInternal`
"""
mutable struct ProbabilisticInternal <: ForecastInternal
    "label of component parameter forecasted"
    label::String
    resolution::Dates.Period
    "forecast availability time"
    initial_time::Dates.DateTime
    "Percentiles for the probabilistic forecast"
    percentiles::Vector{Float64}
    "reference to time series data; timestamp - scalingfactor"
    time_series_uuid::UUIDs.UUID
    "length of this forecast"
    horizon::Int
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
