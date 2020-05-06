#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Deterministic <: Forecast
        label::String
        data::TimeSeries.TimeArray
    end

A deterministic forecast for a particular data field in a Component.

# Arguments
- `label::String`: label of component parameter forecasted
- `data::TimeSeries.TimeArray`: timestamp - scalingfactor
"""
mutable struct Deterministic <: Forecast
    "label of component parameter forecasted"
    label::String
    "timestamp - scalingfactor"
    data::TimeSeries.TimeArray
end


function Deterministic(; label, data, )
    Deterministic(label, data, )
end

"""Get Deterministic label."""
get_label(value::Deterministic) = value.label
"""Get Deterministic data."""
get_data(value::Deterministic) = value.data

"""Set Deterministic label."""
set_label(value::Deterministic, val) = value.label = val
"""Set Deterministic data."""
set_data(value::Deterministic, val) = value.data = val
