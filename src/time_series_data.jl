"""
Abstract type for time_series that are stored in a system.
Users never create them or get access to them.
Stores references to time series data, so a disk read may be required for access.
"""
abstract type TimeSeriesMetadata <: InfrastructureSystemsType end

"""
Abstract type for time_series supplied to users. They are not stored in a system. Instead,
they are generated on demand for the user.
Users can create them. The system will convert them to a subtype of TimeSeriesMetadata for
storage.
Time series data is stored as a field, so reads will always be from memory.
"""
abstract type TimeSeriesData <: Any end

get_horizon(time_series::TimeSeriesData) = length(get_data(time_series))
get_initial_time(time_series::TimeSeriesData) =
    TimeSeries.timestamp(get_data(time_series))[1]
get_scaling_factors(time_series::TimeSeriesData) = get_data(time_series)

function get_resolution(time_series::TimeSeriesData)
    data = get_data(time_series)
    return TimeSeries.timestamp(data)[2] - TimeSeries.timestamp(data)[1]
end

function Base.length(time_series::TimeSeriesData)
    return get_horizon(time_series)
end

function Base.getindex(time_series::TimeSeriesData, args...)
    return _split_time_series(time_series, getindex(get_data(time_series), args...))
end

Base.first(time_series::TimeSeriesData) = head(time_series, 1)

Base.last(time_series::TimeSeriesData) = tail(time_series, 1)

Base.firstindex(time_series::TimeSeriesData) = firstindex(get_data(time_series))

Base.lastindex(time_series::TimeSeriesData) = lastindex(get_data(time_series))

Base.lastindex(time_series::TimeSeriesData, d) = lastindex(get_data(time_series), d)

Base.eachindex(time_series::TimeSeriesData) = eachindex(get_data(time_series))

Base.iterate(time_series::TimeSeriesData, n = 1) = iterate(get_data(time_series), n)

"""
Refer to TimeSeries.when(). Underlying data is copied.
"""
function when(time_series::TimeSeriesData, period::Function, t::Integer)
    new = _split_time_series(time_series, TimeSeries.when(get_data(time_series), period, t))

end

"""
Return a time_series truncated starting with timestamp.
"""
function from(time_series::T, timestamp) where {T <: TimeSeriesData}
    return T(get_label(time_series), TimeSeries.from(get_data(time_series), timestamp))
end

"""
Return a time_series truncated after timestamp.
"""
function to(time_series::T, timestamp) where {T <: TimeSeriesData}
    return T(get_label(time_series), TimeSeries.to(get_data(time_series), timestamp))
end

"""
Return a time_series with only the first num values.
"""
function head(time_series::TimeSeriesData)
    return _split_time_series(time_series, TimeSeries.head(get_data(time_series)))
end

function head(time_series::TimeSeriesData, num)
    return _split_time_series(time_series, TimeSeries.head(get_data(time_series), num))
end

"""
Return a time_series with only the ending num values.
"""
function tail(time_series::TimeSeriesData)
    return _split_time_series(time_series, TimeSeries.tail(get_data(time_series)))
end

function tail(time_series::TimeSeriesData, num)
    return _split_time_series(time_series, TimeSeries.tail(get_data(time_series), num))
end

"""
Creates a new time_series from an existing time_series with a split TimeArray.
"""
function _split_time_series(
    time_series::T,
    data::TimeSeries.TimeArray,
) where {T <: TimeSeriesData}
    vals = []
    for (fname, ftype) in zip(fieldnames(T), fieldtypes(T))
        if ftype <: TimeSeries.TimeArray
            val = data
        elseif ftype <: InfrastructureSystemsInternal
            # Need to create a new UUID.
            continue
        else
            val = getfield(time_series, fname)
        end

        push!(vals, val)
    end

    return T(vals...)
end

function get_resolution(ts::TimeSeries.TimeArray)
    tstamps = TimeSeries.timestamp(ts)
    timediffs = unique([tstamps[ix] - tstamps[ix - 1] for ix in 2:length(tstamps)])

    res = []

    for timediff in timediffs
        if mod(timediff, Dates.Millisecond(Dates.Day(1))) == Dates.Millisecond(0)
            push!(res, Dates.Day(timediff / Dates.Millisecond(Dates.Day(1))))
        elseif mod(timediff, Dates.Millisecond(Dates.Hour(1))) == Dates.Millisecond(0)
            push!(res, Dates.Hour(timediff / Dates.Millisecond(Dates.Hour(1))))
        elseif mod(timediff, Dates.Millisecond(Dates.Minute(1))) == Dates.Millisecond(0)
            push!(res, Dates.Minute(timediff / Dates.Millisecond(Dates.Minute(1))))
        elseif mod(timediff, Dates.Millisecond(Dates.Second(1))) == Dates.Millisecond(0)
            push!(res, Dates.Second(timediff / Dates.Millisecond(Dates.Second(1))))
        else
            throw(DataFormatError("cannot understand the resolution of the time series"))
        end
    end

    if length(res) > 1
        throw(DataFormatError("time series has non-uniform resolution: this is currently not supported"))
    end

    return res[1]
end

get_columns(::Type{<:TimeSeriesMetadata}, ta::TimeSeries.TimeArray) = nothing
