#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct PiecewiseFunction <: Forecast
        label::String
        break_points::Int
        data::TimeSeries.TimeArray
    end

A forecast for  piecewise function data field in a Component.

# Arguments
- `label::String`: label of component parameter forecasted
- `break_points::Int`: Number of break points
- `data::TimeSeries.TimeArray`: timestamp - scalingfactor
"""
mutable struct PiecewiseFunction <: Forecast
    "label of component parameter forecasted"
    label::String
    "Number of break points"
    break_points::Int
    "timestamp - scalingfactor"
    data::TimeSeries.TimeArray
end


function PiecewiseFunction(; label, break_points, data, )
    PiecewiseFunction(label, break_points, data, )
end

"""Get PiecewiseFunction label."""
get_label(value::PiecewiseFunction) = value.label
"""Get PiecewiseFunction break_points."""
get_break_points(value::PiecewiseFunction) = value.break_points
"""Get PiecewiseFunction data."""
get_data(value::PiecewiseFunction) = value.data

"""Set PiecewiseFunction label."""
set_label!(value::PiecewiseFunction, val::String) = value.label = val
"""Set PiecewiseFunction break_points."""
set_break_points!(value::PiecewiseFunction, val::Int) = value.break_points = val
"""Set PiecewiseFunction data."""
set_data!(value::PiecewiseFunction, val::TimeSeries.TimeArray) = value.data = val
