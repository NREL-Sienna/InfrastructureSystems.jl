#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct CostCoefficient <: Forecast
        label::String
        break_points::Int64
        data::TimeSeries.TimeArray
    end

A forecast for cost function data field in a Component.

# Arguments
- `label::String`: label of component parameter forecasted
- `break_points::Int64`: Number of break points
- `data::TimeSeries.TimeArray`: timestamp - scalingfactor
"""
mutable struct CostCoefficient <: Forecast
    "label of component parameter forecasted"
    label::String
    "Number of break points"
    break_points::Int64
    "timestamp - scalingfactor"
    data::TimeSeries.TimeArray
end


function CostCoefficient(; label, break_points, data, )
    CostCoefficient(label, break_points, data, )
end

"""Get CostCoefficient label."""
get_label(value::CostCoefficient) = value.label
"""Get CostCoefficient break_points."""
get_break_points(value::CostCoefficient) = value.break_points
"""Get CostCoefficient data."""
get_data(value::CostCoefficient) = value.data

"""Set CostCoefficient label."""
set_label!(value::CostCoefficient, val::String) = value.label = val
"""Set CostCoefficient break_points."""
set_break_points!(value::CostCoefficient, val::Int64) = value.break_points = val
"""Set CostCoefficient data."""
set_data!(value::CostCoefficient, val::TimeSeries.TimeArray) = value.data = val
