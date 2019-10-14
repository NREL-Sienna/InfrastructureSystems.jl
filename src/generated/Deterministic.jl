#=
This file is auto-generated. Do not edit.
=#

"""A deterministic forecast for a particular data field in a Component."""
mutable struct Deterministic <: Forecast
    label::String  # label of component parameter forecasted
    data::TimeSeries.TimeArray  # timestamp - scalingfactor
end



function Deterministic(; label, data, )
    Deterministic(label, data, )
end


"""Get Deterministic label."""
get_label(value::Deterministic) = value.label
"""Get Deterministic data."""
get_data(value::Deterministic) = value.data
