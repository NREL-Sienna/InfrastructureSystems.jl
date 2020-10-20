const TIME_SERIES_CACHE_SIZE_BYTES = 1024 * 1024

abstract type TimeSeriesCache end

function Base.iterate(cache::TimeSeriesCache, state = nothing)
    if state === nothing
        reset!(cache)
    end

    ta = get_next_time_series_array(cache)
    if ta === nothing
        reset!(cache)
        return nothing
    end

    return ta, 1
end

"""
Return the next TimeSeries.TimeArray.

Returns `nothing` when all data has been read. Call [`reset!`](@ref) to restart.
Call [`get_next_time`](@ref) to check the start time.

# Arguments
- `cache::StaticTimeSeriesCache`: cached instance

Reads from storage if the data is not already in cache.
"""
function get_next_time_series_array(cache::TimeSeriesCache)
    if _get_iterations_remaining(cache) == 0
        return
    end

    next_time = get_next_time(cache)
    if _get_time_series(cache) === nothing || next_time > _get_last_cached_time(cache)
        @debug "get_next_time_series_array update cache" next_time
        _update!(cache)
    else
        @debug "get_next_time_series_array data is in cache" next_time
    end

    len = _get_length_available(cache)
    ta = get_time_series_array(
        _get_component(cache),
        _get_time_series(cache),
        next_time;
        len = len,
        ignore_scaling_factors = _get_ignore_scaling_factors(cache),
    )
    _increment_next_time!(cache, len)
    _decrement_iterations_remaining!(cache)
    return ta
end

"""
Return the timestamp for the next read with [`get_next_time_series_array`](@ref).

Return `nothing` if all data has been read.
"""
function get_next_time(cache::TimeSeriesCache)
    if _get_iterations_remaining(cache) == 0
        return
    end

    return cache.common.next_time
end

"""
Reset parameters in order to start reading data from the beginning with
[`get_next_time_series_array`](@ref)
"""
reset!(cache::TimeSeriesCache) = _reset!(cache.common)

_get_component(c::TimeSeriesCache) = c.common.component
_get_last_cached_time(c::TimeSeriesCache) = c.common.last_cached_time
_get_length_available(c::TimeSeriesCache) = c.common.length_available
_set_length_available!(c::TimeSeriesCache, len) = c.common.length_available = len
_get_length_remaining(c::TimeSeriesCache) = c.common.length_remaining
_decrement_length_remaining!(c::TimeSeriesCache, num) = c.common.length_remaining -= num
_get_name(c::TimeSeriesCache) = c.common.name
_get_ignore_scaling_factors(c::TimeSeriesCache) = c.common.ignore_scaling_factors
_get_type(c::TimeSeriesCache) = c.common.time_series_type
_get_time_series(c::TimeSeriesCache) = c.common.ts
_set_time_series!(c::TimeSeriesCache, ts) = c.common.ts = ts
_get_iterations_remaining(c::TimeSeriesCache) = c.common.iterations_remaining
_decrement_iterations_remaining!(c::TimeSeriesCache) = c.common.iterations_remaining -= 1

mutable struct TimeSeriesCacheCommon
    ts::Union{Nothing, TimeSeriesData}
    time_series_type::DataType
    component::InfrastructureSystemsComponent
    name::String
    orig_next_time::Dates.DateTime
    next_time::Dates.DateTime
    last_cached_time::Dates.DateTime
    "Total length"
    len::Int
    "Cached data available to read"
    length_available::Int
    "Length remaining to be read on disk"
    length_remaining::Int
    "Total iterations to traverse all data"
    num_iterations::Int
    iterations_remaining::Int
    ignore_scaling_factors::Bool

    function TimeSeriesCacheCommon(;
        ts,
        time_series_type,
        component,
        name,
        next_time,
        len,
        num_iterations,
        ignore_scaling_factors,
    )
        new(
            ts,
            time_series_type,
            component,
            name,
            next_time,
            next_time,
            next_time - Dates.Minute(1),
            len,
            0,
            len,
            num_iterations,
            num_iterations,
            ignore_scaling_factors,
        )
    end
end

function _reset!(common::TimeSeriesCacheCommon)
    common.next_time = common.orig_next_time
    common.length_available = common.len
    common.length_remaining = common.len
    common.iterations_remaining = common.num_iterations
    common.ts = nothing
end

mutable struct ForecastCache <: TimeSeriesCache
    common::TimeSeriesCacheCommon
    in_memory_count::Int
    horizon::Int
end

"""
Construct ForecastCache to automatically control caching of forecast data.
Maintains some count of forecast windows in memory based on `cache_size_bytes`.

Call Base.iterate or [`get_next_time_series_array`](@ref) to retrieve data.

# Arguments
- `::Type{T}`: subtype of Forecast
- `component::InfrastructureSystemsComponent`: component
- `name::AbstractString`: forecast name
- `start_time::Union{Nothing, Dates.DateTime} = nothing`: forecast start time
- `horizon::Union{Nothing, Int} = nothing`: forecast horizon
- `cache_size_bytes = TIME_SERIES_CACHE_SIZE_BYTES`: maximum size of data to keep in memory
- `ignore_scaling_factors = false`: controls whether to ignore `scaling_factor_multiplier`
  in the time series instance
"""
function ForecastCache(
    ::Type{T},
    component::InfrastructureSystemsComponent,
    name::AbstractString;
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    horizon::Union{Nothing, Int} = nothing,
    cache_size_bytes = TIME_SERIES_CACHE_SIZE_BYTES,
    ignore_scaling_factors = false,
) where {T <: Forecast}
    metadata_type = time_series_data_to_metadata(T)
    ts_metadata = get_time_series(metadata_type, component, name)
    initial_timestamp = get_initial_timestamp(ts_metadata)
    if start_time === nothing
        start_time = initial_timestamp
    end
    if horizon === nothing
        horizon = get_horizon(ts_metadata)
    end

    # Get one instance to assess data size.
    vals = get_time_series_values(
        T,
        component,
        name;
        start_time = start_time,
        len = get_horizon(ts_metadata),
    )
    row_size = _get_row_size(vals)

    count = get_count(ts_metadata)
    if start_time != initial_timestamp
        count -= (start_time - initial_timestamp) / get_interval(ts_metadata)
    end

    window_size = row_size * horizon
    in_memory_count = minimum((trunc(Int, cache_size_bytes / window_size), count))
    @debug "ForecastCache" row_size window_size in_memory_count

    return ForecastCache(
        TimeSeriesCacheCommon(
            ts = nothing,
            time_series_type = T,
            component = component,
            name = name,
            next_time = start_time,
            len = count,
            num_iterations = count,
            ignore_scaling_factors = ignore_scaling_factors,
        ),
        in_memory_count,
        horizon,
    )
end

function _get_count(cache::ForecastCache)
    return minimum((cache.in_memory_count, _get_length_remaining(cache)))
end

_get_length(c::ForecastCache) = c.horizon

function _update!(cache::ForecastCache)
    if _get_length_remaining(cache) == 0
        throw(ArgumentError("Exceeded time series range"))
    end

    count = _get_count(cache)
    next_time = get_next_time(cache)
    len = _get_length(cache)
    ts = get_time_series(
        _get_type(cache),
        _get_component(cache),
        _get_name(cache);
        start_time = next_time,
        len = len,
        count = count,
    )
    _set_length_available!(cache, len)
    _set_time_series!(cache, ts)
    _set_last_cached_time!(cache, next_time)
    _decrement_length_remaining!(cache, count)
end

function _increment_next_time!(cache::ForecastCache, len)
    cache.common.next_time += get_interval(cache.common.ts)
end

function _set_last_cached_time!(cache::ForecastCache, next_time)
    interval = get_interval(cache.common.ts)
    cache.common.last_cached_time = next_time + (cache.in_memory_count - 1) * interval
end

struct StaticTimeSeriesCache <: TimeSeriesCache
    common::TimeSeriesCacheCommon
    in_memory_rows::Int
end

"""
Construct StaticTimeSeriesCache to automatically control caching of time series data.
Maintains rows of data in memory based on `cache_size_bytes`.

Call Base.iterate or [`get_time_series_array`](@ref) to retrieve data.

# Arguments
- `::Type{T}`: subtype of StaticTimeSeries
- `component::InfrastructureSystemsComponent`: component
- `name::AbstractString`: time series name
- `cache_size_bytes = TIME_SERIES_CACHE_SIZE_BYTES`: maximum size of data to keep in memory
- `ignore_scaling_factors = false`: controls whether to ignore scaling_factor_multiplier
  in the time series instance
"""
function StaticTimeSeriesCache(
    ::Type{T},
    component::InfrastructureSystemsComponent,
    name::AbstractString;
    cache_size_bytes = TIME_SERIES_CACHE_SIZE_BYTES,
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    ignore_scaling_factors = false,
) where {T <: StaticTimeSeries}
    metadata_type = time_series_data_to_metadata(T)
    ts_metadata = get_time_series(metadata_type, component, name)
    initial_timestamp = get_initial_timestamp(ts_metadata)
    if start_time === nothing
        start_time = initial_timestamp
    end

    len = length(ts_metadata)
    if start_time != initial_timestamp
        len -= (start_time - initial_timestamp) / get_resolution(ts_metadata)
    end

    # Get an instance to assess data size.
    vals = get_time_series_values(T, component, name; len = 1)
    row_size = _get_row_size(vals)
    max_chunk_size = row_size * len
    in_memory_rows = minimum((trunc(Int, cache_size_bytes / row_size), len))
    @debug "StaticTimeSeriesCache" row_size max_chunk_size in_memory_rows

    num_iterations = ceil(Int, len / in_memory_rows)
    return StaticTimeSeriesCache(
        TimeSeriesCacheCommon(
            ts = nothing,
            time_series_type = T,
            component = component,
            name = name,
            next_time = start_time,
            len = len,
            num_iterations = num_iterations,
            ignore_scaling_factors = ignore_scaling_factors,
        ),
        in_memory_rows,
    )
end

_get_count(c::StaticTimeSeriesCache) = nothing

function _get_length(cache::StaticTimeSeriesCache)
    return minimum((cache.in_memory_rows, _get_length_remaining(cache)))
end

function _update!(cache::StaticTimeSeriesCache)
    if _get_length_remaining(cache) == 0
        throw(ArgumentError("Exceeded time series range"))
    end

    len = _get_length(cache)
    next_time = get_next_time(cache)
    ts = get_time_series(
        _get_type(cache),
        _get_component(cache),
        _get_name(cache);
        start_time = next_time,
        len = len,
    )
    _set_length_available!(cache, len)
    _set_time_series!(cache, ts)
    _set_last_cached_time!(cache, next_time)
    _decrement_length_remaining!(cache, len)
end

function _set_last_cached_time!(c::StaticTimeSeriesCache, next_time)
    resolution = get_resolution(c.common.ts)
    c.common.last_cached_time = next_time + (c.in_memory_rows - 1) * resolution
end

function _increment_next_time!(cache::StaticTimeSeriesCache, len)
    cache.common.next_time += len * get_resolution(cache.common.ts)
end

function _get_row_size(vals)
    dims = ndims(vals)
    if dims == 1
        row_size = sizeof(vals[1])
    elseif dims == 2
        row_size = sizeof(vals[1, :])
    elseif dims == 3
        row_size = sizeof(vals[1, :, :])
    else
        error("dims=$dims is not supported")
    end

    return row_size
end
