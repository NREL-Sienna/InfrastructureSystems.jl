#=
This file is auto-generated. Do not edit.
=#

"""A Probabilistic forecast for a particular data field in a Component."""
mutable struct Probabilistic{T <: InfrastructureSystemsType} <: Forecast
    component::T
    label::String  # label of component parameter forecasted
    resolution::Dates.Period
    initial_time::Dates.DateTime  # forecast availability time
    percentiles::Vector{Float64}  # Percentiles for the probabilistic forecast
    data::TimeSeries.TimeArray  # timestamp - scalingfactor
    start_index::Int  # starting index of data for this forecast
    horizon::Int  # length of this forecast
    internal::InfrastructureSystemsInternal
end

function Probabilistic(component, label, resolution, initial_time, percentiles, data, start_index, horizon, )
    Probabilistic(component, label, resolution, initial_time, percentiles, data, start_index, horizon, InfrastructureSystemsInternal())
end

function Probabilistic(; component, label, resolution, initial_time, percentiles, data, start_index, horizon, )
    Probabilistic(component, label, resolution, initial_time, percentiles, data, start_index, horizon, )
end

function Probabilistic{T}(component, label, resolution, initial_time, percentiles, data, start_index, horizon, ) where T <: InfrastructureSystemsType
    Probabilistic(component, label, resolution, initial_time, percentiles, data, start_index, horizon, InfrastructureSystemsInternal())
end

"""Get Probabilistic component."""
get_component(value::Probabilistic) = value.component
"""Get Probabilistic label."""
get_label(value::Probabilistic) = value.label
"""Get Probabilistic resolution."""
get_resolution(value::Probabilistic) = value.resolution
"""Get Probabilistic initial_time."""
get_initial_time(value::Probabilistic) = value.initial_time
"""Get Probabilistic percentiles."""
get_percentiles(value::Probabilistic) = value.percentiles
"""Get Probabilistic data."""
get_data(value::Probabilistic) = value.data
"""Get Probabilistic start_index."""
get_start_index(value::Probabilistic) = value.start_index
"""Get Probabilistic horizon."""
get_horizon(value::Probabilistic) = value.horizon
"""Get Probabilistic internal."""
get_internal(value::Probabilistic) = value.internal
