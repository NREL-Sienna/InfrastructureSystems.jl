"""
Return the count of forecast windows.
"""
function get_count(forecast::Union{DeterministicStandard, Probabilistic})
    return length(get_data(forecast))
end

"""
Return all initial times of the forecast.
"""
function get_initial_times(forecast::Union{DeterministicStandard, Probabilistic})
    return keys(get_data(forecast))
end

"""
Return the initial_timestamp of the forecast.
"""
function get_initial_timestamp(forecast::Union{DeterministicStandard, Probabilistic})
    return first(keys(get_data(forecast)))
end

"""
Return the forecast interval as a Dates.Period.
"""
function get_interval(forecast::Union{DeterministicStandard, Probabilistic})
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
    forecast::Union{DeterministicStandard, Probabilistic},
    initial_time::Dates.DateTime,
)
    return TimeSeries.TimeArray(
        make_timestamps(forecast, initial_time),
        forecast.data[initial_time],
    )
end
