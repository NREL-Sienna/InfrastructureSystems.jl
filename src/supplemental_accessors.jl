"""
    get_forecast_value(val::Deterministic, ix)

Return the value of a Deterministic forecast at a given index or DateTime timestamp.
"""
function get_forecast_value(val::Deterministic, ix)
    ta = get_data(val)[ix]
    return TimeSeries.values(ta)[1]
end

"""
    get_forecast_value(forecast::Forecast, ix)

Return the array of values of a forecast at a given index or DateTime timestamp.
"""
function get_forecast_value(forecast::Forecast, ix)
    ta = get_time_series(forecast)[ix]
    return TimeSeries.values(ta)
end
