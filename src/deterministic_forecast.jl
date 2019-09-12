
"""
    make_forecasts(forecast::Deterministic, interval::Dates.Period, horizon::Int)

Make a vector of forecasts by incrementing through a forecast by interval and horizon.
"""
function make_forecasts(forecast::Deterministic, interval::Dates.Period, horizon::Int)
    resolution = get_resolution(forecast)

    if interval < resolution
        throw(ArgumentError("interval=$interval is smaller than resolution=$resolution"))
    end

    if Dates.Second(interval) % Dates.Second(resolution) != Dates.Second(0)
        throw(ArgumentError(
            "interval=$interval is not a multiple of resolution=$resolution"))
    end

    if horizon > get_horizon(forecast)
        throw(ArgumentError(
            "horizon=$horizon is larger than forecast horizon=$(get_horizon(forecast))"))
    end

    interval_as_num = Int(Dates.Second(interval) / Dates.Second(resolution))
    forecasts = Vector{Deterministic}()

    # Index into the TimeArray that backs the master forecast.
    master_forecast_start = get_start_index(forecast)
    master_forecast_end = get_start_index(forecast) + get_horizon(forecast) - 1
    @debug "master indices" master_forecast_start master_forecast_end
    for index in range(master_forecast_start,
                       step=interval_as_num,
                       stop=master_forecast_end)
        start_index = index
        end_index = start_index + horizon - 1
        @debug "new forecast indices" start_index end_index
        if end_index > master_forecast_end
            break
        end

        initial_time = TimeSeries.timestamp(get_data(forecast))[start_index]
        component = get_component(forecast)
        forecast_ = Deterministic(; component=component,
                                  label=get_label(forecast),
                                  resolution=resolution,
                                  initial_time=initial_time,
                                  data=get_data(forecast),
                                  start_index=start_index,
                                  horizon=horizon)
        @info "Created forecast with" initial_time horizon component
        push!(forecasts, forecast_)
    end

    @assert length(forecasts) > 0

    master_end_ts = TimeSeries.timestamp(get_timeseries(forecast))[end]
    last_end_ts = TimeSeries.timestamp(get_timeseries(forecasts[end]))[end]
    if last_end_ts != master_end_ts
        throw(ArgumentError(
            "insufficient data for forecast splitting $master_end_ts $last_end_ts"))
    end

    return forecasts
end
