abstract type Forecast <: TimeSeriesData end

Base.length(ts::Forecast) = get_horizon(ts)
get_name(value::Forecast) = value.name
get_percentiles(value::Forecast) = value.percentiles
get_data(value::Forecast) = value.data
get_scaling_factor_multiplier(value::Forecast) = value.scaling_factor_multiplier

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
