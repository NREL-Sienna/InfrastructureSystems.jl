struct TimeArrayWrapper <: InfrastructureSystemsType
    data::DataStructures.SortedDict{Dates.DateTime, TimeSeries.TimeArray}
    internal::InfrastructureSystemsInternal

    function TimeArrayWrapper(data, internal)
        for v in values(data)
            if length(v) < 2
                throw(ArgumentError("time array length must be at least 2"))
            end
        end
        return new(data, internal)
    end
end

function TimeArrayWrapper(data::TimeSeries.TimeArray)
    data_= Dict(first(TimeSeries.timestamp(data)) => data)
    return TimeArrayWrapper(data_, InfrastructureSystemsInternal())
end

function TimeArrayWrapper(data::DataStructures.SortedDict{Dates.DateTime, TimeSeries.TimeArray})
    return TimeArrayWrapper(data, InfrastructureSystemsInternal())
end

function TimeArrayWrapper(data::Dict{Dates.DateTime, TimeSeries.TimeArray})
    return TimeArrayWrapper(DataStructures.SortedDict(data...), InfrastructureSystemsInternal())
end

get_internal(data) = data.internal

function Base.summary(data::TimeArrayWrapper)
    return "TimeArrayWrapper"
end

function Base.show(io::IO, ::MIME"text/plain", ta::TimeArrayWrapper)
    println(io, "UUID=$(get_uuid(ta))")
    println(io, "data=$(ta.data)")
end

Base.length(ta::TimeArrayWrapper) = length(first(values(ta.data)))
# TODO: Not super efficient for now.
get_initial_time(ta::TimeArrayWrapper) = sort(collect(keys(ta.data)))[1]
get_horizon(ta::TimeArrayWrapper) = length(first(values(ta.data)))
get_resolution(ta::TimeArrayWrapper) =
    TimeSeries.timestamp(first(values(ta.data)))[2] - TimeSeries.timestamp(first(values(ta.data)))[1]
