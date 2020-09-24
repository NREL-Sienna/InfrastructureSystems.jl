"""
Abstract type for time_series that are stored in a system.
Users never create them or get access to them.
Stores references to time series data.
"""
abstract type TimeSeriesMetadata <: InfrastructureSystemsType end

abstract type ForecastMetadata <: TimeSeriesMetadata end

abstract type StaticTimeSeriesMetadata <: TimeSeriesMetadata end

function get_time_series_initial_times(ts_metadata::TimeSeriesMetadata)
    initial_time_stamp = get_initial_time_stamp(ts_metadata)
    interval = get_interval(ts_metadata)
    count = get_count(ts_metadata)
    # TODO DT: is collect required?
    return collect(range(initial_time_stamp; length = count, step = interval))
end

get_initial_time_stamp(ts::StaticTimeSeriesMetadata) = get_initial_time(ts)
Base.length(ts::StaticTimeSeriesMetadata) = get_length(ts)

"""
Abstract type for time_series supplied to users. They are not stored in a system. Instead,
they are generated on demand for the user.
Users can create them. The system will convert them to a subtype of TimeSeriesMetadata for
storage.
"""
abstract type TimeSeriesData end
