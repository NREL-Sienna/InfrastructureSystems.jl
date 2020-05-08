#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Probabilistic <: Forecast
        label::String
        percentiles::Vector{Float64}
        data::TimeSeries.TimeArray
    end

A Probabilistic forecast for a particular data field in a Component.

# Arguments
- `label::String`: label of component parameter forecasted
- `percentiles::Vector{Float64}`: Percentiles for the probabilistic forecast
- `data::TimeSeries.TimeArray`: timestamp - scalingfactor
"""
mutable struct Probabilistic <: Forecast
    "label of component parameter forecasted"
    label::String
    "Percentiles for the probabilistic forecast"
    percentiles::Vector{Float64}
    "timestamp - scalingfactor"
    data::TimeSeries.TimeArray
end


function Probabilistic(; label, percentiles, data, )
    Probabilistic(label, percentiles, data, )
end

"""Get Probabilistic label."""
get_label(value::Probabilistic) = value.label
"""Get Probabilistic percentiles."""
get_percentiles(value::Probabilistic) = value.percentiles
"""Get Probabilistic data."""
get_data(value::Probabilistic) = value.data

"""Set Probabilistic label."""
set_label!(value::Probabilistic, val::String) = value.label = val
"""Set Probabilistic percentiles."""
set_percentiles!(value::Probabilistic, val::Vector{Float64}) = value.percentiles = val
"""Set Probabilistic data."""
set_data!(value::Probabilistic, val::TimeSeries.TimeArray) = value.data = val
