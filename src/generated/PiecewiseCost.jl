#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct PiecewiseCost <: Forecast
        label::String
        break_points::Int
        data::TimeSeries.TimeArray
    end

A forecast for  piecewise cost function data field in a Component.

# Arguments
- `label::String`: label of component parameter forecasted
- `break_points::Int`: Number of break points
- `data::TimeSeries.TimeArray`: timestamp - scalingfactor
"""
mutable struct PiecewiseCost <: Forecast
    "label of component parameter forecasted"
    label::String
    "Number of break points"
    break_points::Int
    "timestamp - scalingfactor"
    data::TimeSeries.TimeArray
end


function PiecewiseCost(; label, break_points, data, )
    PiecewiseCost(label, break_points, data, )
end

"""Get PiecewiseCost label."""
get_label(value::PiecewiseCost) = value.label
"""Get PiecewiseCost break_points."""
get_break_points(value::PiecewiseCost) = value.break_points
"""Get PiecewiseCost data."""
get_data(value::PiecewiseCost) = value.data

"""Set PiecewiseCost label."""
set_label!(value::PiecewiseCost, val::String) = value.label = val
"""Set PiecewiseCost break_points."""
set_break_points!(value::PiecewiseCost, val::Int) = value.break_points = val
"""Set PiecewiseCost data."""
set_data!(value::PiecewiseCost, val::TimeSeries.TimeArray) = value.data = val
