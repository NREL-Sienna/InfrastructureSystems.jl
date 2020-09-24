struct TimeDataContainer <: InfrastructureSystemsType
    data::SortedDict{Dates.DateTime, Array}
    resolution::Dates.Period
    internal::InfrastructureSystemsInternal

    function TimeDataContainer(
        data::SortedDict{Dates.DateTime, Array{T, N}},
        resolution::Dates.Period,
        internal::InfrastructureSystemsInternal,
    ) where {T, N}
        series_length = length(first(values(data)))
        for (k, v) in data
            if length(v) < 2
                throw(ArgumentError("data array length must be at least 2"))
            end
            if length(v) != series_length
                throw(ArgumentError("array lengths don't match. Failed timestamp $k"))
            end
        end
        return new(data, resolution, internal)
    end
end

function TimeDataContainer(
    data::SortedDict{Dates.DateTime, Array{T, N}},
    resolution::Dates.Period,
) where {T, N}
    return TimeDataContainer(data, resolution, InfrastructureSystemsInternal())
end

function TimeDataContainer(
    data::SortedDict{Dates.DateTime, <:TimeSeries.TimeArray},
)
    ta = first(values(data))
    resolution = TimeSeries.timestamp(ta)[2] - TimeSeries.timestamp(ta)[1]
    ta_values = TimeSeries.values.(values(data))
    _data = SortedDict(keys(data) .=> ta_values)
    return TimeDataContainer(_data, resolution)
end

function TimeDataContainer(data::Dict{Dates.DateTime, <:TimeSeries.TimeArray})
    return TimeDataContainer(SortedDict(data...),)
end

function TimeDataContainer(data::TimeSeries.TimeArray)
    @show _data = Dict(first(TimeSeries.timestamp(data)) => data)
    return TimeDataContainer(_data)
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

function get_array_for_hdf(ta::TimeDataContainer)
    # TODO: Implement for more dimensions.
    # TODO: Is this storing the data efficiently?
    if length(ta.data) == 1
        return TimeSeries.values(first(values(ta.data)))
    else
        return hcat(TimeSeries.values.(values(ta.data))...)
    end
end
