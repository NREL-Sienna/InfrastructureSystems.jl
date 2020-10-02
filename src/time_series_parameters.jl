const UNINITIALIZED_DATETIME = Dates.DateTime(Dates.Minute(0))
const UNINITIALIZED_LENGTH = 0
const UNINITIALIZED_PERIOD = Dates.Period(Dates.Minute(0))

mutable struct ForecastParameters <: InfrastructureSystemsType
    horizon::Int
    initial_timestamp::Dates.DateTime
    interval::Dates.Period
    count::Int
end

function ForecastParameters(;
    horizon = UNINITIALIZED_LENGTH,
    initial_timestamp = UNINITIALIZED_DATETIME,
    interval = UNINITIALIZED_PERIOD,
    count = UNINITIALIZED_LENGTH,
)
    return ForecastParameters(horizon, initial_timestamp, interval, count)
end

function _is_uninitialized(params::ForecastParameters)
    return params.horizon == UNINITIALIZED_LENGTH &&
           params.initial_timestamp == UNINITIALIZED_DATETIME &&
           params.interval == UNINITIALIZED_PERIOD &&
           params.count == UNINITIALIZED_LENGTH
end

function reset_info!(params::ForecastParameters)
    params.horizon = UNINITIALIZED_LENGTH
    params.initial_timestamp = UNINITIALIZED_DATETIME
    params.interval = UNINITIALIZED_PERIOD
    params.count = UNINITIALIZED_LENGTH
end

function generate_forecast_initial_times(params::ForecastParameters)
    return generate_initial_times(params.initial_timestamp, params.count, params.interval)
end

mutable struct TimeSeriesParameters <: InfrastructureSystemsType
    resolution::Dates.Period
    forecast_params::ForecastParameters
end

function TimeSeriesParameters(;
    resolution = UNINITIALIZED_PERIOD,
    forecast_params = ForecastParameters(),
)
    return TimeSeriesParameters(resolution, forecast_params)
end

function reset_info!(params::TimeSeriesParameters)
    params.resolution = UNINITIALIZED_PERIOD
    reset_info!(params.forecast_params)
    @info "Reset system time series parameters."
end

function _is_uninitialized(params::TimeSeriesParameters)
    return params.resolution == UNINITIALIZED_PERIOD
end

function _check_time_series(params::TimeSeriesParameters, ts::TimeSeriesData)
    res = get_resolution(ts)
    if res != params.resolution
        throw(ConflictingInputsError(
            "time series resolution $res does not match system " *
            "resolution $(params.resolution)",
        ))
    end
    _check_forecast_params(params, ts)
end

_check_forecast_params(params::TimeSeriesParameters, ts::StaticTimeSeries) = nothing

function _check_forecast_params(ts_params::TimeSeriesParameters, forecast::Forecast)
    count = get_count(forecast)
    horizon = get_horizon(forecast)
    initial_timestamp = get_initial_timestamp(forecast)

    params = ts_params.forecast_params
    if count != params.count
        throw(ConflictingInputsError("forecast count $count does not match system count $(params.count)"))
    end

    if horizon != params.horizon
        throw(ConflictingInputsError("forecast horizon $horizon does not match system horizon $(params.horizon)"))
    end

    if initial_timestamp != params.initial_timestamp
        throw(ConflictingInputsError(
            "forecast initial_timestamp $initial_timestamp does not match system " *
            "initial_timestamp $(params.initial_timestamp)",
        ))
    end

    return
end

function check_add_time_series!(params::TimeSeriesParameters, ts::TimeSeriesData)
    _check_time_series_lengths(ts)
    if _is_uninitialized(params)
        # This is the first time series added.
        params.resolution = get_resolution(ts)
    end

    if ts isa Forecast && _is_uninitialized(params.forecast_params)
        params.forecast_params.horizon = get_horizon(ts)
        params.forecast_params.initial_timestamp = get_initial_timestamp(ts)
        params.forecast_params.interval = get_interval(ts)
        params.forecast_params.count = get_count(ts)
    end

    _check_time_series(params, ts)
    return
end

function _check_time_series_lengths(ts::StaticTimeSeries)
    data = get_data(ts)
    if length(data) < 2
        throw(ArgumentError("data array length must be at least 2: $(length(data))"))
    end
    if length(data) != length(ts)
        throw(ConflictingInputsError("length mismatch: $(length(data)) $(length(ts))"))
    end

    timestamps = TimeSeries.timestamp(data)
    difft = timestamps[2] - timestamps[1]
    if difft != get_resolution(ts)
        throw(ConflictingInputsError("resolution mismatch: $difft $(get_resolution(ts))"))
    end
    return
end

function _check_time_series_lengths(ts::Forecast)
    horizon = get_horizon(ts)
    if horizon < 2
        throw(ArgumentError("horizon must be at least 2: $horizon"))
    end
    for data in values(get_data(ts))
        if length(data) != horizon
            throw(ConflictingInputsError("length mismatch: $(length(data)) $horizon"))
        end
    end
end

get_forecast_count(params::TimeSeriesParameters) = params.forecast_params.count
generate_forecast_initial_times(params::TimeSeriesParameters) =
    generate_forecast_initial_times(params.forecast_params)
get_forecast_horizon(params::TimeSeriesParameters) = params.forecast_params.horizon
get_forecast_initial_timestamp(params::TimeSeriesParameters) =
    params.forecast_params.initial_timestamp
get_forecast_interval(params::TimeSeriesParameters) = params.forecast_params.interval
get_time_series_resolution(params::TimeSeriesParameters) = params.resolution

function get_forecast_total_period(p::TimeSeriesParameters)
    f = p.forecast_params
    _is_uninitialized(f) && return Dates.Second(0)
    return get_total_period(
        f.initial_timestamp,
        f.count,
        f.interval,
        f.horizon,
        p.resolution,
    )
end
