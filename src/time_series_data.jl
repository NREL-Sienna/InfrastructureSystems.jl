struct TimeSeriesData <: InfrastructureSystemsType
    data::TimeSeries.TimeArray
    internal::InfrastructureSystemsInternal

    function TimeSeriesData(data, internal)
        if length(data) < 2
            throw(ArgumentError("time array length must be at least 2"))
        end

        return new(data, internal)
    end
end

function TimeSeriesData(data)
    return TimeSeriesData(data, InfrastructureSystemsInternal())
end

function Base.summary(data::TimeSeriesData)
    return "TimeSeriesData"
end

function Base.show(io::IO, ::MIME"text/plain", ts::TimeSeriesData)
    println(io, "UUID=$(get_uuid(ts))")
    println(io, "data=$(ts.data)")
end

Base.length(ts::TimeSeriesData) = length(ts.data)
get_initial_time(ts::TimeSeriesData) = TimeSeries.timestamp(ts.data)[1]
get_horizon(ts::TimeSeriesData) = length(ts.data)
get_resolution(ts::TimeSeriesData) = TimeSeries.timestamp(ts.data)[2] -
                                     TimeSeries.timestamp(ts.data)[1]

#function get_time_series(data::TimeSeriesData)
#    if !isnothing(data)
#        return data[Symbol(data.component_name)]
#    end
#
#    ta = read_timeseries(data.file_path)
#    return ta[Symbol(data.component_name)]
#end

