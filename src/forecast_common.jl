"""
Return the count of forecast windows.
"""
function get_count(forecast::Union{Deterministic, Probabilistic})
    return length(get_data(forecast))
end

"""
Return all initial times of the forecast.
"""
function get_initial_times(forecast::Union{Deterministic, Probabilistic})
    return keys(get_data(forecast))
end

"""
Return the initial_timestamp of the forecast.
"""
function get_initial_timestamp(forecast::Union{Deterministic, Probabilistic})
    return first(keys(get_data(forecast)))
end

"""
Return the forecast interval as a Dates.Period.
"""
function get_interval(forecast::Union{Deterministic, Probabilistic})
    its = get_initial_times(forecast)
    if length(its) == 1
        return Dates.Second(0)
    end
    first_it, state = iterate(its)
    second_it, state = iterate(its, state)
    return second_it - first_it
end

"""
Return the forecast window corresponsing to initial_time.
"""
function get_window(
    forecast::Union{Deterministic, Probabilistic},
    initial_time::Dates.DateTime;
    len::Union{Nothing, Int} = nothing,
)
    horizon = get_horizon(forecast)
    if len === nothing
        len = horizon
    end

    data = forecast.data[initial_time]
    if len != horizon
        data = data[1:len]
    end

    return TimeSeries.TimeArray(make_timestamps(forecast, initial_time, len), data)
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
