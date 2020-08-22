const UNINITIALIZED_DATETIME = Dates.DateTime(Dates.Minute(0))
const UNINITIALIZED_PERIOD = Dates.Period(Dates.Minute(0))
const UNINITIALIZED_HORIZON = 0

"""Container for forecasts and their metadata.."""
mutable struct ForecastMetadata <: InfrastructureSystemsType
    resolution::Dates.Period
    horizon::Int64
end

function ForecastMetadata(;
    resolution = UNINITIALIZED_PERIOD,
    horizon = UNINITIALIZED_HORIZON,
)
    return ForecastMetadata(resolution, horizon)
end

function reset_info!(forecasts::ForecastMetadata)
    forecasts.resolution = UNINITIALIZED_PERIOD
    forecasts.horizon = UNINITIALIZED_HORIZON
    @info "Reset system forecast information."
end

function is_uninitialized(forecasts::ForecastMetadata)
    return forecasts.resolution == UNINITIALIZED_PERIOD &&
           forecasts.horizon == UNINITIALIZED_HORIZON
end

function _verify_forecast(metadata::ForecastMetadata, forecast::ForecastInternal)
    if forecast.resolution != metadata.resolution
        throw(DataFormatError(
            "Forecast resolution $(forecast.resolution) does not match system " *
            "resolution $(metadata.resolution)",
        ))
    end

    if get_horizon(forecast) != metadata.horizon
        throw(DataFormatError(
            "Forecast horizon $(get_horizon(forecast)) does not match system horizon " *
            "$(metadata.horizon)",
        ))
    end
end

function check_add_forecast!(metadata::ForecastMetadata, forecast::ForecastInternal)
    if is_uninitialized(metadata)
        # This is the first forecast added.
        metadata.horizon = get_horizon(forecast)
        metadata.resolution = forecast.resolution
    end

    # This will throw if something is invalid.
    _verify_forecast(metadata, forecast)
end

"""Return the horizon for all forecasts."""
get_forecasts_horizon(forecasts::ForecastMetadata)::Int64 = forecasts.horizon

"""Return the resolution for all forecasts."""
get_forecasts_resolution(forecasts::ForecastMetadata)::Dates.Period = forecasts.resolution
