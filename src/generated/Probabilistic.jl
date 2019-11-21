#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Probabilistic <: Forecast
        label::String
        percentiles::Vector{Float64}
        data::TimeSeries.TimeArray
        ext::Union{Nothing, Dict{String, Any}}
    end

A Probabilistic forecast for a particular data field in a Component.

# Arguments
- `label::String`: label of component parameter forecasted
- `percentiles::Vector{Float64}`: Percentiles for the probabilistic forecast
- `data::TimeSeries.TimeArray`: timestamp - scalingfactor
- `ext::Union{Nothing, Dict{String, Any}}`
"""
mutable struct Probabilistic <: Forecast
    "label of component parameter forecasted"
    label::String
    "Percentiles for the probabilistic forecast"
    percentiles::Vector{Float64}
    "timestamp - scalingfactor"
    data::TimeSeries.TimeArray
    ext::Union{Nothing, Dict{String, Any}}
end



function Probabilistic(; label, percentiles, data, ext, )
    Probabilistic(label, percentiles, data, ext, )
end


"""Get Probabilistic label."""
get_label(value::Probabilistic) = value.label
"""Get Probabilistic percentiles."""
get_percentiles(value::Probabilistic) = value.percentiles
"""Get Probabilistic data."""
get_data(value::Probabilistic) = value.data
"""Get Probabilistic ext."""
get_ext(value::Probabilistic) = value.ext
