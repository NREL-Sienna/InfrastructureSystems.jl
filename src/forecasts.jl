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
function get_initial_times(f::Forecast)
    return get_initial_times(get_initial_timestamp(f), get_count(f), get_interval(f))
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

"""
Iterate over all forecast windows.
"""
function iterate_windows(forecast::Forecast)
    return (get_window(forecast, it) for it in keys(forecast.data))
end

"""
Return the Dates.DateTime corresponding to an interval index.
"""
function index_to_initial_time(forecast::Forecast, index::Int)
    return get_initial_timestamp(forecast) + get_interval(forecast) * index
end

function make_timestamps(forecast::Forecast, initial_time::Dates.DateTime, len = nothing)
    if len === nothing
        len = get_horizon(forecast)
    end

    return range(initial_time; length = len, step = get_resolution(forecast))
end
