const UNINITIALIZED_DATETIME = Dates.DateTime(Dates.Minute(0))
const UNINITIALIZED_PERIOD = Dates.Period(Dates.Minute(0))
const UNINITIALIZED_HORIZON = 0

mutable struct TimeSeriesParameters <: InfrastructureSystemsType
    resolution::Dates.Period
    horizon::Int
end

function TimeSeriesParameters(;
    resolution = UNINITIALIZED_PERIOD,
    horizon = UNINITIALIZED_HORIZON,
)
    return TimeSeriesParameters(resolution, horizon)
end

function reset_info!(time_series::TimeSeriesParameters)
    time_series.resolution = UNINITIALIZED_PERIOD
    time_series.horizon = UNINITIALIZED_HORIZON
    @info "Reset system time_series information."
end

function is_uninitialized(time_series::TimeSeriesParameters)
    return time_series.resolution == UNINITIALIZED_PERIOD &&
           time_series.horizon == UNINITIALIZED_HORIZON
end

function _verify_time_series(params::TimeSeriesParameters, time_series::TimeSeriesMetadata)
    if time_series.resolution != params.resolution
        throw(DataFormatError(
            "time series resolution $(time_series.resolution) does not match system " *
            "resolution $(params.resolution)",
        ))
    end

    if get_horizon(time_series) != params.horizon
        throw(DataFormatError(
            "time series horizon $(get_horizon(time_series)) does not match system " *
            "horizon $(params.horizon)",
        ))
    end
    return
end

function check_add_time_series!(params::TimeSeriesParameters, ts::TimeSeriesMetadata)
    if is_uninitialized(params)
        # This is the first time_series added.
        params.horizon = get_horizon(ts)
        params.resolution = ts.resolution
    end

    # This will throw if something is invalid.
    _verify_time_series(params, ts)
    return
end

function _verify_time_series(
    params::TimeSeriesParameters,
    time_series::SingleTimeSeriesMetadata,
)
    if time_series.resolution != params.resolution
        throw(DataFormatError(
            "time series resolution $(time_series.resolution) does not match system " *
            "resolution $(params.resolution)",
        ))
    end
    return
end

function check_add_time_series!(params::TimeSeriesParameters, ts::SingleTimeSeriesMetadata)
    if is_uninitialized(params)
        # This is the first time_series added.
        params.resolution = ts.resolution
    end

    # This will throw if something is invalid.
    _verify_time_series(params, ts)
    return
end

"""Return the horizon for all time_series."""
get_time_series_horizon(time_series::TimeSeriesParameters) = time_series.horizon

"""Return the resolution for all time_series."""
get_time_series_resolution(time_series::TimeSeriesParameters) = time_series.resolution
