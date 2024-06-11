"""
Abstract type for time_series that are stored in a system.
Users never create them or get access to them.
Stores references to TimeSeriesData.
"""
abstract type TimeSeriesMetadata <: InfrastructureSystemsType end

abstract type ForecastMetadata <: TimeSeriesMetadata end

abstract type StaticTimeSeriesMetadata <: TimeSeriesMetadata end

get_count(ts::StaticTimeSeriesMetadata) = 1
get_initial_timestamp(ts::StaticTimeSeriesMetadata) = get_initial_timestamp(ts)
Base.length(ts::StaticTimeSeriesMetadata) = get_length(ts)
Base.length(ts::ForecastMetadata) = get_horizon_count(ts)

function get_horizon_count(metadata::ForecastMetadata)
    return get_horizon_count(get_horizon(metadata), get_resolution(metadata))
end

"""
Abstract type for time series stored in the system.
Components store references to these through TimeSeriesMetadata values so that data can
reside on storage media instead of memory.
"""
abstract type TimeSeriesData <: InfrastructureSystemsType end

# Subtypes must implement
# - Base.length
# - get_resolution
# - make_time_array
# - eltype_data

abstract type AbstractTimeSeriesParameters <: InfrastructureSystemsType end

struct StaticTimeSeriesParameters <: AbstractTimeSeriesParameters end

@kwdef struct ForecastParameters <: AbstractTimeSeriesParameters
    horizon::Dates.Period
    initial_timestamp::Dates.DateTime
    interval::Dates.Period
    count::Int
    resolution::Dates.Period
end

check_params_compatibility(::Nothing, forecast_params::ForecastParameters) = nothing

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
