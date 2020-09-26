"""
Abstract type for time_series that are stored in a system.
Users never create them or get access to them.
Stores references to TimeSeriesData.
"""
abstract type TimeSeriesMetadata <: InfrastructureSystemsType end

abstract type ForecastMetadata <: TimeSeriesMetadata end

abstract type StaticTimeSeriesMetadata <: TimeSeriesMetadata end

function get_time_series_initial_times(ts_metadata::ForecastMetadata)
    initial_timestamp = get_initial_timestamp(ts_metadata)
    interval = get_interval(ts_metadata)
    count = get_count(ts_metadata)
    return collect(range(initial_timestamp; length = count, step = interval))
end

function get_time_series_initial_times(ts_metadata::StaticTimeSeriesMetadata)
    return Vector{Dates.DateTime}(get_initial_time(ts_metadata))
end

get_count(ts::StaticTimeSeriesMetadata) = 1
get_initial_timestamp(ts::StaticTimeSeriesMetadata) = get_initial_time(ts)
Base.length(ts::StaticTimeSeriesMetadata) = get_length(ts)
Base.length(ts::ForecastMetadata) = get_horizon(ts)

"""
Abstract type for time series stored in the system.
Components store references to these through TimeSeriesMetadata values so that data can
reside on storage media instead of memory.
"""
abstract type TimeSeriesData <: InfrastructureSystemsComponent end
