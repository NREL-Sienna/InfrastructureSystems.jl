abstract type Forecast <: TimeSeriesData end

# Subtypes of Forecast must implement
# - get_count
# - get_data
# - get_horizon
# - get_name
# - get_scaling_factor_multiplier
# - get_window
# - iterate_windows

Base.length(ts::Forecast) = get_count(ts)

"""
Return the initial times in the forecast.
"""
function generate_initial_times(f::Forecast)
    return generate_initial_times(get_initial_timestamp(f), get_count(f), get_interval(f))
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
Return the count of forecast windows.
"""
function get_count(forecast::Forecast)
    return length(get_data(forecast))
end

"""
Return the forecast interval as a Dates.Period.
"""
function get_interval(forecast::Forecast)
    k = keys(get_data(forecast))
    if length(k) == 1
        return Dates.Second(0)
    end
    first_key, state = iterate(k)
    second_key, state = iterate(k, state)
    return second_key - first_key
end

"""
Return the Dates.DateTime corresponding to an interval index.
"""
function index_to_initial_time(forecast::Forecast, index::Int)
    return get_initial_timestamp(forecast) + get_interval(forecast) * index
end

function make_timestamps(forecast::Forecast, initial_time::Dates.DateTime)
    return range(
        initial_time;
        length = get_horizon(forecast),
        step = get_resolution(forecast),
    )
end
