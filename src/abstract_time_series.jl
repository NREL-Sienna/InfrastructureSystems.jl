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
Base.length(ts::ForecastMetadata) = get_horizon(ts)

"""
Abstract type for time series stored in the system.
Components store references to these through TimeSeriesMetadata values so that data can
reside on storage media instead of memory.
"""
abstract type TimeSeriesData <: InfrastructureSystemsComponent end

# Subtypes must implement
# - Base.length
# - get_resolution
# - make_time_array
# - eltype_data

abstract type AbstractTimeSeriesParameters <: InfrastructureSystemsType end

struct StaticTimeSeriesParameters <: AbstractTimeSeriesParameters end

@kwdef struct ForecastParameters <: AbstractTimeSeriesParameters
    horizon::Int
    initial_timestamp::Dates.DateTime
    interval::Dates.Period
    count::Int
    resolution::Dates.Period
end
