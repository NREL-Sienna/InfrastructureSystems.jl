#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct TimeSeriesData <: AbstractTimeSeriesData
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
mutable struct TimeSeriesData <: AbstractTimeSeriesData
    "user-defined label"
    label::String
    "timestamp - scalingfactor"
    data::TimeSeries.TimeArray
    "Applicable when the time series data are scaling factors. Called on the associated component to convert the values."
    scaling_factor_multiplier::Union{Nothing, Function}
end


function TimeSeriesData(; label, data, scaling_factor_multiplier=nothing, )
    TimeSeriesData(label, data, scaling_factor_multiplier, )
end

"""Get [`TimeSeriesData`](@ref) `label`."""
get_label(value::TimeSeriesData) = value.label
"""Get [`TimeSeriesData`](@ref) `data`."""
get_data(value::TimeSeriesData) = value.data
"""Get [`TimeSeriesData`](@ref) `scaling_factor_multiplier`."""
get_scaling_factor_multiplier(value::TimeSeriesData) = value.scaling_factor_multiplier

"""Set [`TimeSeriesData`](@ref) `label`."""
set_label!(value::TimeSeriesData, val) = value.label = val
"""Set [`TimeSeriesData`](@ref) `data`."""
set_data!(value::TimeSeriesData, val) = value.data = val
"""Set [`TimeSeriesData`](@ref) `scaling_factor_multiplier`."""
set_scaling_factor_multiplier!(value::TimeSeriesData, val) = value.scaling_factor_multiplier = val

TimeSeriesData(label, data) = TimeSeriesData(label = label, data = data)
