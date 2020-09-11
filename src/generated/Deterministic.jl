#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Deterministic <: TimeSeriesData
        label::String
        data::TimeSeries.TimeArray
    end

A deterministic time series for a particular data field in a Component.

# Arguments
- `label::String`: user-defined label
- `data::TimeSeries.TimeArray`: timestamp - scalingfactor
"""
mutable struct Deterministic <: TimeSeriesData
    "user-defined label"
    label::String
    "timestamp - scalingfactor"
    data::TimeSeries.TimeArray
end


function Deterministic(; label, data, )
    Deterministic(label, data, )
end

"""Get [`Deterministic`](@ref) `label`."""
get_label(value::Deterministic) = value.label
"""Get [`Deterministic`](@ref) `data`."""
get_data(value::Deterministic) = value.data

"""Set [`Deterministic`](@ref) `label`."""
set_label!(value::Deterministic, val) = value.label = val
"""Set [`Deterministic`](@ref) `data`."""
set_data!(value::Deterministic, val) = value.data = val

