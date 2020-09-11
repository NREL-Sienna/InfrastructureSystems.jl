#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Probabilistic <: TimeSeriesData
        label::String
        percentiles::Vector{Float64}
        data::TimeSeries.TimeArray
    end

A Probabilistic time series for a particular data field in a Component.

# Arguments
- `label::String`: user-defined label
- `percentiles::Vector{Float64}`: Percentiles for the probabilistic time series
- `data::TimeSeries.TimeArray`: timestamp - scalingfactor
"""
mutable struct Probabilistic <: TimeSeriesData
    "user-defined label"
    label::String
    "Percentiles for the probabilistic time series"
    percentiles::Vector{Float64}
    "timestamp - scalingfactor"
    data::TimeSeries.TimeArray
end


function Probabilistic(; label, percentiles, data, )
    Probabilistic(label, percentiles, data, )
end

"""Get [`Probabilistic`](@ref) `label`."""
get_label(value::Probabilistic) = value.label
"""Get [`Probabilistic`](@ref) `percentiles`."""
get_percentiles(value::Probabilistic) = value.percentiles
"""Get [`Probabilistic`](@ref) `data`."""
get_data(value::Probabilistic) = value.data

"""Set [`Probabilistic`](@ref) `label`."""
set_label!(value::Probabilistic, val) = value.label = val
"""Set [`Probabilistic`](@ref) `percentiles`."""
set_percentiles!(value::Probabilistic, val) = value.percentiles = val
"""Set [`Probabilistic`](@ref) `data`."""
set_data!(value::Probabilistic, val) = value.data = val

