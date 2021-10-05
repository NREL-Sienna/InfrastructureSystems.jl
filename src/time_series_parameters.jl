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

function check_params_compatibility(params::ForecastParameters, other::ForecastParameters)
    _is_uninitialized(params) && return true

    if other.count != params.count
        throw(
            ConflictingInputsError(
                "forecast count $(other.count) does not match system count $(params.count)",
            ),
        )
    end

    if other.horizon != params.horizon
        throw(
            ConflictingInputsError(
                "forecast horizon $(other.horizon) does not match system horizon $(params.horizon)",
            ),
        )
    end

    if other.initial_timestamp != params.initial_timestamp
        throw(
            ConflictingInputsError(
                "forecast initial_timestamp $(other.initial_timestamp) does not match system " *
                "initial_timestamp $(params.initial_timestamp)",
            ),
        )
    end

    return
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
    return
end

function get_forecast_initial_times(params::ForecastParameters)
    return get_initial_times(params.initial_timestamp, params.count, params.interval)
end

function set_parameters!(params::ForecastParameters, other::ForecastParameters)
    params.horizon = other.horizon
    params.initial_timestamp = other.initial_timestamp
    params.interval = other.interval
    params.count = other.count
    return
end

function set_parameters!(params::ForecastParameters, forecast::Forecast)
    set_parameters!(params, TimeSeriesParameters(forecast).forecast_params)
    return
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

function TimeSeriesParameters(ts::StaticTimeSeries)
    return TimeSeriesParameters(resolution = get_resolution(ts))
end

function TimeSeriesParameters(ts::Forecast)
    forecast_params = ForecastParameters(
        count = get_count(ts),
        horizon = get_horizon(ts),
        initial_timestamp = get_initial_timestamp(ts),
        interval = get_interval(ts),
    )
    return TimeSeriesParameters(get_resolution(ts), forecast_params)
end

function TimeSeriesParameters(
    initial_timestamp::Dates.DateTime,
    resolution::Dates.Period,
    len::Int,
    horizon::Int,
    interval::Dates.Period,
)
    if interval == Dates.Second(0)
        count = 1
    else
        last_timestamp = initial_timestamp + resolution * (len - 1)
        last_initial_time = last_timestamp - resolution * (horizon - 1)

        # Reduce last_initial_time to the nearest interval if necessary.
        diff =
            Dates.Millisecond(last_initial_time - initial_timestamp) %
            Dates.Millisecond(interval)
        if diff != Dates.Millisecond(0)
            last_initial_time -= diff
        end
        count =
            Dates.Millisecond(last_initial_time - initial_timestamp) /
            Dates.Millisecond(interval) + 1
    end
    fparams = ForecastParameters(
        horizon = horizon,
        initial_timestamp = initial_timestamp,
        interval = interval,
        count = count,
    )
    return TimeSeriesParameters(resolution, fparams)
end

function reset_info!(params::TimeSeriesParameters)
    params.resolution = UNINITIALIZED_PERIOD
    reset_info!(params.forecast_params)
    @info "Reset system time series parameters."
end

function _is_uninitialized(params::TimeSeriesParameters)
    return params.resolution == UNINITIALIZED_PERIOD
end

"""
Return true if `params` match `other` or if one of them is uninitialized.
"""
function check_params_compatibility(
    params::TimeSeriesParameters,
    other::TimeSeriesParameters,
)
    _is_uninitialized(params) && return true

    if other.resolution != params.resolution
        throw(
            ConflictingInputsError(
                "time series resolution $(other.resolution) does not match system " *
                "resolution $(params.resolution)",
            ),
        )
    end

    # `other` might be for a static time series and not have forecast params
    if !_is_uninitialized(other.forecast_params)
        check_params_compatibility(params.forecast_params, other.forecast_params)
    end
end

function check_add_time_series(params::TimeSeriesParameters, ts::TimeSeriesData)
    check_params_compatibility(params, TimeSeriesParameters(ts))
    _check_time_series_lengths(ts)
    return
end

function set_parameters!(params::TimeSeriesParameters, ts::StaticTimeSeries)
    params.resolution = get_resolution(ts)
    return
end

function set_parameters!(params::TimeSeriesParameters, forecast::Forecast)
    params.resolution = get_resolution(forecast)
    set_parameters!(params.forecast_params, forecast)
    return
end

function set_parameters!(params::TimeSeriesParameters, other::TimeSeriesParameters)
    if _is_uninitialized(params)
        # This is the first time series added.
        params.resolution = other.resolution
    end

    if _is_uninitialized(params.forecast_params)
        set_parameters!(params.forecast_params, other.forecast_params)
    end

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
    for window in iterate_windows(ts)
        if size(window)[1] != horizon
            throw(ConflictingInputsError("length mismatch: $(size(window)[1]) $horizon"))
        end
    end
end

get_forecast_window_count(params::TimeSeriesParameters) = params.forecast_params.count
get_forecast_initial_times(params::TimeSeriesParameters) =
    get_forecast_initial_times(params.forecast_params)
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
