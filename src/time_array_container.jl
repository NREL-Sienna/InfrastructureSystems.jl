struct TimeArrayContainer <: InfrastructureSystemsType
    data::DataStructures.SortedDict{Dates.DateTime, TimeSeries.TimeArray}
    internal::InfrastructureSystemsInternal

    function TimeArrayContainer(data, internal)
        for v in values(data)
            if length(v) < 2
                throw(ArgumentError("time array length must be at least 2"))
            end
        end
        return new(data, internal)
    end
end

function TimeArrayContainer(data::TimeSeries.TimeArray)
    data_= Dict(first(TimeSeries.timestamp(data)) => data)
    return TimeArrayContainer(data_, InfrastructureSystemsInternal())
end

function TimeArrayContainer(data::DataStructures.SortedDict{Dates.DateTime, TimeSeries.TimeArray})
    return TimeArrayContainer(data, InfrastructureSystemsInternal())
end

function TimeArrayContainer(data::Dict{Dates.DateTime, TimeSeries.TimeArray})
    return TimeArrayContainer(DataStructures.SortedDict(data...), InfrastructureSystemsInternal())
end

get_internal(data) = data.internal

function Base.summary(data::TimeArrayContainer)
    return "TimeArrayContainer"
end

function Base.show(io::IO, ::MIME"text/plain", ta::TimeArrayContainer)
    println(io, "UUID=$(get_uuid(ta))")
    println(io, "data=$(ta.data)")
end

Base.length(ta::TimeArrayContainer) = length(first(values(ta.data)))
# TODO: Not super efficient for now.
get_initial_time(ta::TimeArrayContainer) = collect(keys(ta.data))[1]
get_horizon(ta::TimeArrayContainer) = length(first(values(ta.data)))
get_resolution(ta::TimeArrayContainer) =
    TimeSeries.timestamp(first(values(ta.data)))[2] - TimeSeries.timestamp(first(values(ta.data)))[1]
function get_interval(ta::TimeArrayContainer)
    if length(ta.data) < 2
        throw(ArgumentError("get_interval is an invalid operation for contingous data"))
    end
    keys_ = collect(keys(ta.data))
    return keys_[2] - keys_[1]
end
