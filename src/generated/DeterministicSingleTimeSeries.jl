#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct DeterministicSingleTimeSeries <: AbstractDeterministic
        single_time_series::SingleTimeSeries
        initial_timestamp::Dates.DateTime
        interval::Dates.Period
        count::Int
        horizon::Int
    end

A deterministic forecast for a particular data field in a Component that wraps a SingleTimeSeries.

# Arguments
- `single_time_series::SingleTimeSeries`: wrapped SingleTimeSeries object
- `initial_timestamp::Dates.DateTime`: time series availability time
- `interval::Dates.Period`: step time between forecast windows
- `count::Int`: number of forecast windows
- `horizon::Int`: length of this time series
"""
mutable struct DeterministicSingleTimeSeries <: AbstractDeterministic
    "wrapped SingleTimeSeries object"
    single_time_series::SingleTimeSeries
    "time series availability time"
    initial_timestamp::Dates.DateTime
    "step time between forecast windows"
    interval::Dates.Period
    "number of forecast windows"
    count::Int
    "length of this time series"
    horizon::Int
end


function DeterministicSingleTimeSeries(; single_time_series, initial_timestamp, interval, count, horizon, )
    DeterministicSingleTimeSeries(single_time_series, initial_timestamp, interval, count, horizon, )
end

"""Get [`DeterministicSingleTimeSeries`](@ref) `single_time_series`."""
get_single_time_series(value::DeterministicSingleTimeSeries) = value.single_time_series
"""Get [`DeterministicSingleTimeSeries`](@ref) `initial_timestamp`."""
get_initial_timestamp(value::DeterministicSingleTimeSeries) = value.initial_timestamp
"""Get [`DeterministicSingleTimeSeries`](@ref) `interval`."""
get_interval(value::DeterministicSingleTimeSeries) = value.interval
"""Get [`DeterministicSingleTimeSeries`](@ref) `count`."""
get_count(value::DeterministicSingleTimeSeries) = value.count
"""Get [`DeterministicSingleTimeSeries`](@ref) `horizon`."""
get_horizon(value::DeterministicSingleTimeSeries) = value.horizon

"""Set [`DeterministicSingleTimeSeries`](@ref) `single_time_series`."""
set_single_time_series!(value::DeterministicSingleTimeSeries, val) = value.single_time_series = val
"""Set [`DeterministicSingleTimeSeries`](@ref) `initial_timestamp`."""
set_initial_timestamp!(value::DeterministicSingleTimeSeries, val) = value.initial_timestamp = val
"""Set [`DeterministicSingleTimeSeries`](@ref) `interval`."""
set_interval!(value::DeterministicSingleTimeSeries, val) = value.interval = val
"""Set [`DeterministicSingleTimeSeries`](@ref) `count`."""
set_count!(value::DeterministicSingleTimeSeries, val) = value.count = val
"""Set [`DeterministicSingleTimeSeries`](@ref) `horizon`."""
set_horizon!(value::DeterministicSingleTimeSeries, val) = value.horizon = val

