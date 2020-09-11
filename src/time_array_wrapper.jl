struct TimeArrayWrapper <: InfrastructureSystemsType
    data::TimeSeries.TimeArray
    internal::InfrastructureSystemsInternal

    function TimeArrayWrapper(data, internal)
        if length(data) < 2
            throw(ArgumentError("time array length must be at least 2"))
        end

        return new(data, internal)
    end
end

function TimeArrayWrapper(data)
    return TimeArrayWrapper(data, InfrastructureSystemsInternal())
end

get_internal(data) = data.internal

function Base.summary(data::TimeArrayWrapper)
    return "TimeArrayWrapper"
end

function Base.show(io::IO, ::MIME"text/plain", ta::TimeArrayWrapper)
    println(io, "UUID=$(get_uuid(ta))")
    println(io, "data=$(ta.data)")
end

Base.length(ta::TimeArrayWrapper) = length(ta.data)
get_initial_time(ta::TimeArrayWrapper) = TimeSeries.timestamp(ta.data)[1]
get_horizon(ta::TimeArrayWrapper) = length(ta.data)
get_resolution(ta::TimeArrayWrapper) =
    TimeSeries.timestamp(ta.data)[2] - TimeSeries.timestamp(ta.data)[1]
