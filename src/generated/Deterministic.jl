#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Deterministic <: Forecast
        label::String
        data::TimeSeries.TimeArray
        ext::Union{Nothing, Dict{String, Any}}
    end

A deterministic forecast for a particular data field in a Component.

# Arguments
- `label::String`: label of component parameter forecasted
- `data::TimeSeries.TimeArray`: timestamp - scalingfactor
- `ext::Union{Nothing, Dict{String, Any}}`
"""
mutable struct Deterministic <: Forecast
    "label of component parameter forecasted"
    label::String
    "timestamp - scalingfactor"
    data::TimeSeries.TimeArray
    ext::Union{Nothing, Dict{String, Any}}
end



function Deterministic(; label, data, ext, )
    Deterministic(label, data, ext, )
end


"""Get Deterministic label."""
get_label(value::Deterministic) = value.label
"""Get Deterministic data."""
get_data(value::Deterministic) = value.data
"""Get Deterministic ext."""
get_ext(value::Deterministic) = value.ext
