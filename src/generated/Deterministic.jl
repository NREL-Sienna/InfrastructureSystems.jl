#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Deterministic <: TimeSeriesData
        label::String
        data::TimeSeries.TimeArray
        scaling_factor_multiplier::Union{Nothing, Function}
    end

A deterministic time series for a particular data field in a Component.

# Arguments
- `label::String`: user-defined label
- `data::TimeSeries.TimeArray`: timestamp - scalingfactor
- `scaling_factor_multiplier::Union{Nothing, Function}`: Applicable when the time series data are scaling factors. Called on the associated component to convert the values.
"""
mutable struct Deterministic <: TimeSeriesData
    "user-defined label"
    label::String
    "timestamp - scalingfactor"
    data::TimeSeries.TimeArray
    "Applicable when the time series data are scaling factors. Called on the associated component to convert the values."
    scaling_factor_multiplier::Union{Nothing, Function}
end


function Deterministic(; label, data, scaling_factor_multiplier=nothing, )
    Deterministic(label, data, scaling_factor_multiplier, )
end

"""Get [`Deterministic`](@ref) `label`."""
get_label(value::Deterministic) = value.label
"""Get [`Deterministic`](@ref) `data`."""
get_data(value::Deterministic) = value.data
"""Get [`Deterministic`](@ref) `scaling_factor_multiplier`."""
get_scaling_factor_multiplier(value::Deterministic) = value.scaling_factor_multiplier

"""Set [`Deterministic`](@ref) `label`."""
set_label!(value::Deterministic, val) = value.label = val
"""Set [`Deterministic`](@ref) `data`."""
set_data!(value::Deterministic, val) = value.data = val
"""Set [`Deterministic`](@ref) `scaling_factor_multiplier`."""
set_scaling_factor_multiplier!(value::Deterministic, val) = value.scaling_factor_multiplier = val

Deterministic(label, data) = Determinstic(label = label, data = data)
