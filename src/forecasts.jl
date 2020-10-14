abstract type Forecast <: TimeSeriesData end

# Subtypes of Forecast must implement
# - get_count
# - get_horizon
# - get_initial_times
# - get_initial_timestamp
# - get_name
# - get_scaling_factor_multiplier
# - get_window
# - iterate_windows

Base.length(ts::Forecast) = get_count(ts)

abstract type AbstractDeterministic <: Forecast end

# This method requires that the forecast type implement a `get_data` method like
# Deterministic.
function eltype_data_common(forecast::Forecast)
    return eltype(first(values(get_data(forecast))))
end

# This method requires that the forecast type implement a `get_data` method like
# Deterministic.
function get_count_common(forecast)
    return length(get_data(forecast))
end

# This method requires that the forecast type implement a `get_data` method like
# Deterministic. Allows for optimized execution.
function get_horizon_common(forecast)
    return length(first(values(get_data(forecast))))
end

"""
Return the initial times in the forecast.
"""
function get_initial_times(f::Forecast)
    return get_initial_times(get_initial_timestamp(f), get_count(f), get_interval(f))
end

# This method requires that the forecast type implement a `get_data` method like
# Deterministic. Allows for optimized execution.
function get_initial_times_common(forecast::Forecast)
    return keys(get_data(forecast))
end

"""
Return the total period covered by the forecast.
"""
function get_total_period(f::Forecast)
    return get_total_period(
        get_initial_timestamp(f),
        get_count(f),
        get_interval(f),
        get_horizon(f),
        get_resolution(f),
    )
end

"""
Return the forecast window corresponsing to interval index.
"""
function get_window(forecast::Forecast, index::Int; len = nothing)
    return get_window(forecast, index_to_initial_time(forecast, index); len = len)
end

function iterate_windows_common(forecast)
    return (get_window(forecast, it) for it in keys(get_data(forecast)))
end

"""
Return the Dates.DateTime corresponding to an interval index.
"""
function index_to_initial_time(forecast::Forecast, index::Int)
    return get_initial_timestamp(forecast) + get_interval(forecast) * index
end

"""
Return a TimeSeries.TimeArray for one forecast window.
"""
function make_time_array(
    forecast::Forecast,
    start_time::Dates.DateTime;
    len::Union{Nothing, Int} = nothing,
)
    return get_window(forecast, start_time; len = len)
end

function make_timestamps(forecast::Forecast, initial_time::Dates.DateTime, len = nothing)
    if len === nothing
        len = get_horizon(forecast)
    end

    return range(initial_time; length = len, step = get_resolution(forecast))
end

# This method requires that the forecast type implement a `get_data` method like
# Deterministic. Allows for optimized execution.
function get_initial_timestamp_common(forecast)
    return first(keys(get_data(forecast)))
end

# This method requires that the forecast type implement a `get_data` method like
# Deterministic. Allows for optimized execution.
function get_interval_common(forecast)
    its = get_initial_times(forecast)
    if length(its) == 1
        return Dates.Second(0)
    end
    first_it, state = iterate(its)
    second_it, state = iterate(its, state)
    return second_it - first_it
end

# This method requires that the forecast type implement a `get_data` method like
# Deterministic.
function get_window_common(
    forecast,
    initial_time::Dates.DateTime;
    len::Union{Nothing, Int} = nothing,
)
    horizon = get_horizon(forecast)
    if len === nothing
        len = horizon
    end

    data = get_data(forecast)[initial_time]
    if len != horizon
        data = data[1:len]
    end

    return TimeSeries.TimeArray(make_timestamps(forecast, initial_time, len), data)
end
