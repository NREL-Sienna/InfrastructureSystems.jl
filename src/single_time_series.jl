get_initial_time(time_series::SingleTimeSeries) =
    TimeSeries.timestamp(get_data(time_series))[1]

function get_resolution(time_series::SingleTimeSeries)
    data = get_data(time_series)
    return TimeSeries.timestamp(data)[2] - TimeSeries.timestamp(data)[1]
end

function Base.getindex(time_series::SingleTimeSeries, args...)
    return split_time_series(time_series, getindex(get_data(time_series), args...))
end

Base.first(time_series::SingleTimeSeries) = head(time_series, 1)

Base.last(time_series::SingleTimeSeries) = tail(time_series, 1)

Base.firstindex(time_series::SingleTimeSeries) = firstindex(get_data(time_series))

Base.lastindex(time_series::SingleTimeSeries) = lastindex(get_data(time_series))

Base.lastindex(time_series::SingleTimeSeries, d) = lastindex(get_data(time_series), d)

Base.eachindex(time_series::SingleTimeSeries) = eachindex(get_data(time_series))

Base.iterate(time_series::SingleTimeSeries, n = 1) = iterate(get_data(time_series), n)

"""
Refer to TimeSeries.when(). Underlying data is copied.
"""
function when(time_series::SingleTimeSeries, period::Function, t::Integer)
    new = split_time_series(time_series, TimeSeries.when(get_data(time_series), period, t))

end

"""
Return a time_series truncated starting with timestamp.
"""
function from(time_series::T, timestamp) where {T <: SingleTimeSeries}
    return T(;
        name = get_name(time_series),
        data = TimeSeries.from(get_data(time_series), timestamp),
    )
end

"""
Return a time_series truncated after timestamp.
"""
function to(time_series::T, timestamp) where {T <: SingleTimeSeries}
    return T(;
        name = get_name(time_series),
        data = TimeSeries.to(get_data(time_series), timestamp),
    )
end

"""
Return a time_series with only the first num values.
"""
function head(time_series::SingleTimeSeries)
    return split_time_series(time_series, TimeSeries.head(get_data(time_series)))
end

function head(time_series::SingleTimeSeries, num)
    return split_time_series(time_series, TimeSeries.head(get_data(time_series), num))
end

"""
Return a time_series with only the ending num values.
"""
function tail(time_series::SingleTimeSeries)
    return split_time_series(time_series, TimeSeries.tail(get_data(time_series)))
end

function tail(time_series::SingleTimeSeries, num)
    return split_time_series(time_series, TimeSeries.tail(get_data(time_series), num))
end

"""
Creates a new time_series from an existing time_series with a split TimeArray.
"""
function split_time_series(
    time_series::T,
    data::TimeSeries.TimeArray,
) where {T <: SingleTimeSeries}
    vals = []
    for (fname, ftype) in zip(fieldnames(T), fieldtypes(T))
        if ftype <: TimeSeries.TimeArray
            val = data
        # Use the same UUID
        #elseif ftype <: InfrastructureSystemsInternal
        #    # Need to create a new UUID.
        #    continue
        else
            val = getfield(time_series, fname)
        end

        push!(vals, val)
    end

    return T(vals...)
end

get_columns(::Type{<:TimeSeriesMetadata}, ta::TimeSeries.TimeArray) = nothing

function get_array_for_hdf(ts::SingleTimeSeries)
    return TimeSeries.values(ts.data)
end
