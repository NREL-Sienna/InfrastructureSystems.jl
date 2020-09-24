struct TimeDataContainer <: InfrastructureSystemsType
    data::DataStructures.SortedDict{Dates.DateTime, Vector{Float64}}
    resolution::Dates.Period
    internal::InfrastructureSystemsInternal

    function TimeDataContainer(data, resolution, internal)
        for v in values(data)
            if length(v) < 2
                throw(ArgumentError("time array length must be at least 2"))
            end
        end
        return new(data, resolution, internal)
    end
end

function TimeDataContainer(data::TimeSeries.TimeArray)
    resolution = TimeSeries.timestamp(data)[2] - TimeSeries.timestamp(data)[1]
    _data = Dict(first(TimeSeries.timestamp(data)) => TimeSeries.values(data))
    return TimeDataContainer(_data, resolution, InfrastructureSystemsInternal())
end

function TimeDataContainer(
    data::DataStructures.SortedDict{Dates.DateTime, Vector{Float64}},
    resolution::Dates.Period,
)
    return TimeDataContainer(data, resolution, InfrastructureSystemsInternal())
end

function TimeDataContainer(
    data::DataStructures.SortedDict{Dates.DateTime, TimeSeries.TimeArray},
)
    ta = first(values(data))
    resolution = TimeSeries.timestamp(ta)[2] - TimeSeries.timestamp(ta)[1]
    ta_values = TimeSeries.values.(values(data))
    _data = DataStructures.SortedDict(keys(data) .=> ta_values)
    return TimeDataContainer(_data, resolution)
end

function TimeDataContainer(data::Dict{Dates.DateTime, TimeSeries.TimeArray})
    return TimeDataContainer(DataStructures.SortedDict(data...),)
end

get_internal(data) = data.internal

function Base.summary(data::TimeDataContainer)
    return "TimeDataContainer"
end

function Base.show(io::IO, ::MIME"text/plain", ta::TimeDataContainer)
    println(io, "UUID=$(get_uuid(ta))")
    println(io, "data=$(ta.data)")
end

Base.length(ta::TimeDataContainer) = length(first(values(ta.data)))
get_initial_time(ta::TimeDataContainer) = collect(keys(ta.data))[1]
get_horizon(ta::TimeDataContainer) = length(ta)
get_resolution(ta::TimeDataContainer) = ta.resolution
function get_interval(ta::TimeDataContainer)
    if length(ta.data) < 2
        throw(ArgumentError("get_interval is an invalid operation for continguous data"))
    end
    k = keys(ta.data)
    first_key, state = iterate(k)
    second_key, state = iterate(k, state)
    return second_key - first_key
end
get_count(ta::TimeDataContainer) = length(ta.data)
