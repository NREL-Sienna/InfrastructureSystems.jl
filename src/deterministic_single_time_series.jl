#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct DeterministicSingleTimeSeries <: Forecast
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
mutable struct DeterministicSingleTimeSeries <: Forecast
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
    internal::InfrastructureSystemsInternal
end

function DeterministicSingleTimeSeries(;
    single_time_series,
    initial_timestamp,
    interval,
    count,
    horizon,
    internal = InfrastructureSystemsInternal(),
)
    DeterministicSingleTimeSeries(
        single_time_series,
        initial_timestamp,
        interval,
        count,
        horizon,
        internal,
    )
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
"""Get [`DeterministicSingleTimeSeries`](@ref) `internal`."""
get_internal(value::DeterministicSingleTimeSeries) = value.internal
get_resolution(value::DeterministicSingleTimeSeries) =
    get_resolution(value.single_time_series)

"""Set [`DeterministicSingleTimeSeries`](@ref) `single_time_series`."""
set_single_time_series!(value::DeterministicSingleTimeSeries, val) =
    value.single_time_series = val
"""Set [`DeterministicSingleTimeSeries`](@ref) `initial_timestamp`."""
set_initial_timestamp!(value::DeterministicSingleTimeSeries, val) =
    value.initial_timestamp = val
"""Set [`DeterministicSingleTimeSeries`](@ref) `interval`."""
set_interval!(value::DeterministicSingleTimeSeries, val) = value.interval = val
"""Set [`DeterministicSingleTimeSeries`](@ref) `count`."""
set_count!(value::DeterministicSingleTimeSeries, val) = value.count = val
"""Set [`DeterministicSingleTimeSeries`](@ref) `horizon`."""
set_horizon!(value::DeterministicSingleTimeSeries, val) = value.horizon = val
"""Set [`DeterministicSingleTimeSeries`](@ref) `internal`."""
set_internal!(value::DeterministicSingleTimeSeries, val) = value.internal = val

function get_array_for_hdf(forecast::DeterministicSingleTimeSeries)
    return get_array_for_hdf(forecast.single_time_series)
end

function make_time_array(forecast::DeterministicSingleTimeSeries)
    # Artificial limitation to reduce scope.
    @assert get_count(forecast) == 1
    timestamps = range(
        get_initial_timestamp(forecast);
        step = get_resolution(forecast),
        length = get_horizon(forecast),
    )
    data = first(values(get_data(forecast)))
    return TimeSeries.TimeArray(timestamps, data)
end

function get_window(forecast::DeterministicSingleTimeSeries, initial_time::Dates.DateTime)
    tdiff = Dates.Millisecond(initial_time - forecast.initial_timestamp)
    if tdiff % Dates.Millisecond(forecast.interval) != Dates.Millisecond(0)
        throw(ArgumentError("initial_time=$initial_time is not on a window boundary"))
    end

    ta = get_data(forecast.single_time_series)
    resolution = get_resolution(forecast)
    end_time = initial_time + (forecast.horizon - 1) * resolution
    timestamps = TimeSeries.timestamp(ta)
    for timestamp in (initial_time, end_time)
        @assert timestamp >= first(timestamps) && timestamp <= last(timestamps) "invalid " *
                                                                                "timestamp=$timestamp is not within $(first(timestamps)) - $(last(timestamps))"
    end
    return ta[initial_time:resolution:end_time]
end

function iterate_windows(forecast::DeterministicSingleTimeSeries)
    initial_times =
        range(forecast.initial_timestamp; step = forecast.interval, length = forecast.count)
    return (get_window(forecast, it) for it in initial_times)
end
