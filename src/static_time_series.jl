abstract type StaticTimeSeries <: TimeSeriesData end

Base.length(ts::StaticTimeSeries) = length(get_data(ts))
get_initial_timestamp(ts::StaticTimeSeries) = TimeSeries.timestamp(get_data(ts))[1]
