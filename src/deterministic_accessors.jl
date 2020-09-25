"""
Return the forecast window corresponsing to initial_time.
"""
function get_window(forecast::Deterministic, initial_time::Dates.DateTime)
    return TimeSeries.TimeArray(
        make_timestamps(forecast, initial_time),
        forecast.data[initial_time],
    )
end

"""
Return the forecast window corresponsing to interval index.
"""
function get_window(forecast::Deterministic, index::Int)
    return get_window(forecast, index_to_initial_time(forecast, index))
end

"""
Iterate over all forecast windows.
"""
function iterate_windows(forecast::Deterministic)
    return (get_window(forecast, it) for it in keys(forecast.data))
end

function get_array_for_hdf(forecast::Deterministic)
    return hcat(values(forecast.data)...)
end
