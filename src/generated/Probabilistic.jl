#=
This file is auto-generated. Do not edit.
=#

"""A Probabilistic forecast for a particular data field in a Component."""
mutable struct Probabilistic <: Forecast
    label::String  # label of component parameter forecasted
    percentiles::Vector{Float64}  # Percentiles for the probabilistic forecast
    data::TimeSeries.TimeArray  # timestamp - scalingfactor
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
