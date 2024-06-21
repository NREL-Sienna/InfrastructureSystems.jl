abstract type AbstractTimeSeriesParameters <: InfrastructureSystemsType end

struct StaticTimeSeriesParameters <: AbstractTimeSeriesParameters end

@kwdef struct ForecastParameters <: AbstractTimeSeriesParameters
    horizon::Dates.Period
    initial_timestamp::Dates.DateTime
    interval::Dates.Period
    count::Int
    resolution::Dates.Period
end

make_time_series_parameters(::StaticTimeSeries) = StaticTimeSeriesParameters()

make_time_series_parameters(ts::Forecast) = ForecastParameters(;
    horizon = get_horizon(ts),
    initial_timestamp = get_initial_timestamp(ts),
    interval = get_interval(ts),
    count = get_count(ts),
    resolution = get_resolution(ts),
)

check_params_compatibility(
    sys_sts_params::StaticTimeSeriesParameters,
    ::Union{Nothing, ForecastParameters},
    ts::StaticTimeSeries,
) = check_params_compatibility(sys_sts_params, make_time_series_parameters(ts))

check_params_compatibility(
    ::StaticTimeSeriesParameters,
    sys_forecast_params::Union{Nothing, ForecastParameters},
    ts::Forecast,
) = check_params_compatibility(sys_forecast_params, make_time_series_parameters(ts))

check_params_compatibility(::StaticTimeSeriesParameters, ::StaticTimeSeriesParameters) =
    nothing

check_params_compatibility(::Nothing, ::ForecastParameters) = nothing

function check_params_compatibility(
    system_params::ForecastParameters,
    forecast_params::ForecastParameters,
)
    if forecast_params.count != system_params.count
        throw(
            ConflictingInputsError(
                "forecast count $(forecast_params.count) does not match system count $(system_params.count)",
            ),
        )
    end

    if forecast_params.initial_timestamp != system_params.initial_timestamp
        throw(
            ConflictingInputsError(
                "forecast initial_timestamp $(forecast_params.initial_timestamp) does not match system " *
                "initial_timestamp $(system_params.initial_timestamp)",
            ),
        )
    end

    if forecast_params.horizon != system_params.horizon
        throw(
            ConflictingInputsError(
                "forecast horizon $(forecast_params.horizon) " *
                "does not match system horizon $(system_params.horizon)",
            ),
        )
    end
end
