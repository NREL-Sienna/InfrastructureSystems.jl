"""Get Forecast component name."""
get_forecast_component_name(forecast::Forecast) = get_name(get_component(forecast))

"""gets the value of a Deterministic forecast at a given index or DateTime timestamp"""
function get_forecast_value(val::Deterministic, ix)
    ta = get_data(val)[ix]
    return TimeSeries.values(ta)[1]

end

"""gets the array of values of a forecast at a given index or DateTime timestamp"""
function get_forecast_value(forecast::Forecast, ix)
    ta = get_data(forecast)[ix]
    return TimeSeries.values(ta)

end

