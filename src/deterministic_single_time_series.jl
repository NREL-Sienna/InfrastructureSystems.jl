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
- `interval::Dates.Period`: time step between forecast windows
- `count::Int`: number of forecast windows
- `horizon::Int`: length of this time series
"""
mutable struct DeterministicSingleTimeSeries <: AbstractDeterministic
    "wrapped SingleTimeSeries object"
    single_time_series::SingleTimeSeries
    "time series availability time"
    initial_timestamp::Dates.DateTime
    "time step between forecast windows"
    interval::Dates.Period
    "number of forecast windows"
    count::Int
    "length of this time series"
    horizon::Int
end

function DeterministicSingleTimeSeries(;
    single_time_series,
    initial_timestamp,
    interval,
    count,
    horizon,
)
    DeterministicSingleTimeSeries(
        single_time_series,
        initial_timestamp,
        interval,
        count,
        horizon,
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

eltype_data(ts::DeterministicSingleTimeSeries) = eltype_data(ts.single_time_series)
get_scaling_factor_multiplier(ts::DeterministicSingleTimeSeries) =
    get_scaling_factor_multiplier(ts.single_time_series)

function get_array_for_hdf(forecast::DeterministicSingleTimeSeries)
    return get_array_for_hdf(forecast.single_time_series)
end

get_resolution(val::DeterministicSingleTimeSeries) = get_resolution(val.single_time_series)

function get_window(
    forecast::DeterministicSingleTimeSeries,
    initial_time::Dates.DateTime;
    len::Union{Nothing, Int} = nothing,
)
    tdiff = Dates.Millisecond(initial_time - forecast.initial_timestamp)
    interval_ms = Dates.Millisecond(forecast.interval)
    if interval_ms != Dates.Millisecond(0) && tdiff % interval_ms != Dates.Millisecond(0)
        throw(ArgumentError("initial_time=$initial_time is not on a window boundary"))
    end

    if len === nothing
        len = forecast.horizon
    end

    ta = get_data(forecast.single_time_series)
    resolution = get_resolution(forecast)
    end_time = initial_time + (len - 1) * resolution
    timestamps = TimeSeries.timestamp(ta)
    for timestamp in (initial_time, end_time)
        @assert timestamp >= first(timestamps) && timestamp <= last(timestamps) "invalid " *
                                                                                "timestamp=$timestamp is not within $(first(timestamps)) - $(last(timestamps))"
    end

    return ta[initial_time:resolution:end_time]
end

function iterate_windows(forecast::DeterministicSingleTimeSeries)
    if get_count(forecast) == 1
        return (get_window(forecast, get_initial_timestamp(forecast)),)
    end

    initial_times =
        range(forecast.initial_timestamp; step = forecast.interval, length = forecast.count)
    return (get_window(forecast, it) for it in initial_times)
end

function deserialize_deterministic_from_single_time_series(
    storage::TimeSeriesStorage,
    ts_metadata::DeterministicMetadata,
    rows,
    columns,
    last_index,
)
    @debug "deserializing a SingleTimeSeries"
    horizon = get_horizon(ts_metadata)
    interval = get_interval(ts_metadata)
    resolution = get_resolution(ts_metadata)
    if length(rows) != horizon
        throw(ArgumentError("Transforming SingleTimeSeries to Deterministic requires a full horizon: $rows"))
    end

    sts_rows =
        _translate_deterministic_offsets(horizon, interval, resolution, columns, last_index)
    sts = deserialize_time_series(
        SingleTimeSeries,
        storage,
        SingleTimeSeriesMetadata(ts_metadata),
        sts_rows,
        UnitRange(1, 1),
    )
    initial_timestamp =
        get_initial_timestamp(ts_metadata) + (columns.start - 1) * get_interval(ts_metadata)
    return DeterministicSingleTimeSeries(
        sts,
        initial_timestamp,
        interval,
        length(columns),
        horizon,
    )
end

function _translate_deterministic_offsets(
    horizon,
    interval,
    resolution,
    columns,
    last_index,
)
    interval = Dates.Millisecond(interval)
    interval_offset = Int(interval / resolution)
    s_index = (columns.start - 1) * interval_offset + 1
    e_index = (columns.stop - 1) * interval_offset + horizon
    @debug "translated offsets" horizon columns s_index e_index last_index
    @assert s_index <= last_index
    @assert e_index <= last_index
    return UnitRange(s_index, e_index)
end
