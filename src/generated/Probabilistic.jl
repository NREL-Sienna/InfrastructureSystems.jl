#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Probabilistic <: TimeSeriesData
        label::String
        percentiles::Vector{Float64}
        data::TimeSeries.TimeArray
        scaling_factor_multiplier::Union{Nothing, Function}
    end

A Probabilistic time series for a particular data field in a Component.

# Arguments
- `label::String`: user-defined label
- `percentiles::Vector{Float64}`: Percentiles for the probabilistic time series
- `data::TimeSeries.TimeArray`: timestamp - scalingfactor
- `scaling_factor_multiplier::Union{Nothing, Function}`: Applicable when the time series data are scaling factors. Called on the associated component to convert the values.
"""
mutable struct Probabilistic <: TimeSeriesData
    "user-defined label"
    label::String
    "Percentiles for the probabilistic time series"
    percentiles::Vector{Float64}
    "timestamp - scalingfactor"
    data::TimeSeries.TimeArray
    "Applicable when the time series data are scaling factors. Called on the associated component to convert the values."
    scaling_factor_multiplier::Union{Nothing, Function}
end


function Probabilistic(; label, percentiles, data, scaling_factor_multiplier=nothing, )
    Probabilistic(label, percentiles, data, scaling_factor_multiplier, )
end

"""Get [`Probabilistic`](@ref) `label`."""
get_label(value::Probabilistic) = value.label
"""Get [`Probabilistic`](@ref) `percentiles`."""
get_percentiles(value::Probabilistic) = value.percentiles
"""Get [`Probabilistic`](@ref) `data`."""
get_data(value::Probabilistic) = value.data
"""Get [`Probabilistic`](@ref) `scaling_factor_multiplier`."""
get_scaling_factor_multiplier(value::Probabilistic) = value.scaling_factor_multiplier

"""Set [`Probabilistic`](@ref) `label`."""
set_label!(value::Probabilistic, val) = value.label = val
"""Set [`Probabilistic`](@ref) `percentiles`."""
set_percentiles!(value::Probabilistic, val) = value.percentiles = val
"""Set [`Probabilistic`](@ref) `data`."""
set_data!(value::Probabilistic, val) = value.data = val
"""Set [`Probabilistic`](@ref) `scaling_factor_multiplier`."""
set_scaling_factor_multiplier!(value::Probabilistic, val) = value.scaling_factor_multiplier = val

Probabilistic(label, percentiles, data) = Probabilistic(label = label, data = data, percentiles = percentiles)
