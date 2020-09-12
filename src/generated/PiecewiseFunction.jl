#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct PiecewiseFunction <: TimeSeriesData
        label::String
        break_points::Int
        data::TimeSeries.TimeArray
        scaling_factor_multiplier::Union{Nothing, Function}
    end

A time series for  piecewise function data field in a Component.

# Arguments
- `label::String`: user-defined label
- `break_points::Int`: Number of break points
- `data::TimeSeries.TimeArray`: timestamp - scalingfactor
- `scaling_factor_multiplier::Union{Nothing, Function}`: Applicable when the time series data are scaling factors. Called on the associated component to convert the values.
"""
mutable struct PiecewiseFunction <: TimeSeriesData
    "user-defined label"
    label::String
    "Number of break points"
    break_points::Int
    "timestamp - scalingfactor"
    data::TimeSeries.TimeArray
    "Applicable when the time series data are scaling factors. Called on the associated component to convert the values."
    scaling_factor_multiplier::Union{Nothing, Function}
end


function PiecewiseFunction(; label, break_points, data, scaling_factor_multiplier=nothing, )
    PiecewiseFunction(label, break_points, data, scaling_factor_multiplier, )
end

"""Get [`PiecewiseFunction`](@ref) `label`."""
get_label(value::PiecewiseFunction) = value.label
"""Get [`PiecewiseFunction`](@ref) `break_points`."""
get_break_points(value::PiecewiseFunction) = value.break_points
"""Get [`PiecewiseFunction`](@ref) `data`."""
get_data(value::PiecewiseFunction) = value.data
"""Get [`PiecewiseFunction`](@ref) `scaling_factor_multiplier`."""
get_scaling_factor_multiplier(value::PiecewiseFunction) = value.scaling_factor_multiplier

"""Set [`PiecewiseFunction`](@ref) `label`."""
set_label!(value::PiecewiseFunction, val) = value.label = val
"""Set [`PiecewiseFunction`](@ref) `break_points`."""
set_break_points!(value::PiecewiseFunction, val) = value.break_points = val
"""Set [`PiecewiseFunction`](@ref) `data`."""
set_data!(value::PiecewiseFunction, val) = value.data = val
"""Set [`PiecewiseFunction`](@ref) `scaling_factor_multiplier`."""
set_scaling_factor_multiplier!(value::PiecewiseFunction, val) = value.scaling_factor_multiplier = val

