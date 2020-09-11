#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct PiecewiseFunction <: TimeSeriesData
        label::String
        break_points::Int
        data::TimeSeries.TimeArray
    end

A time series for  piecewise function data field in a Component.

# Arguments
- `label::String`: user-defined label
- `break_points::Int`: Number of break points
- `data::TimeSeries.TimeArray`: timestamp - scalingfactor
"""
mutable struct PiecewiseFunction <: TimeSeriesData
    "user-defined label"
    label::String
    "Number of break points"
    break_points::Int
    "timestamp - scalingfactor"
    data::TimeSeries.TimeArray
end


function PiecewiseFunction(; label, break_points, data, )
    PiecewiseFunction(label, break_points, data, )
end

"""Get [`PiecewiseFunction`](@ref) `label`."""
get_label(value::PiecewiseFunction) = value.label
"""Get [`PiecewiseFunction`](@ref) `break_points`."""
get_break_points(value::PiecewiseFunction) = value.break_points
"""Get [`PiecewiseFunction`](@ref) `data`."""
get_data(value::PiecewiseFunction) = value.data

"""Set [`PiecewiseFunction`](@ref) `label`."""
set_label!(value::PiecewiseFunction, val) = value.label = val
"""Set [`PiecewiseFunction`](@ref) `break_points`."""
set_break_points!(value::PiecewiseFunction, val) = value.break_points = val
"""Set [`PiecewiseFunction`](@ref) `data`."""
set_data!(value::PiecewiseFunction, val) = value.data = val

