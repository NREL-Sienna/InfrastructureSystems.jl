time_series_data_to_metadata(::Type{<:AbstractDeterministic}) = DeterministicMetadata
time_series_data_to_metadata(::Type{Probabilistic}) = ProbabilisticMetadata
time_series_data_to_metadata(::Type{Scenarios}) = ScenariosMetadata
time_series_data_to_metadata(::Type{SingleTimeSeries}) = SingleTimeSeriesMetadata

time_series_metadata_to_data(::ProbabilisticMetadata) = Probabilistic
time_series_metadata_to_data(::ScenariosMetadata) = Scenarios
time_series_metadata_to_data(::SingleTimeSeriesMetadata) = SingleTimeSeries

function time_series_metadata_to_data(ts_metadata::DeterministicMetadata)
    return ts_metadata.time_series_type
end

is_time_series_sub_type(::Type{<:TimeSeriesMetadata}, ::Type{<:TimeSeriesData}) = false
is_time_series_sub_type(::Type{SingleTimeSeriesMetadata}, ::Type{StaticTimeSeries}) = true
is_time_series_sub_type(::Type{DeterministicMetadata}, ::Type{AbstractDeterministic}) = true
is_time_series_sub_type(::Type{DeterministicMetadata}, ::Type{Forecast}) = true
is_time_series_sub_type(::Type{ProbabilisticMetadata}, ::Type{Forecast}) = true
is_time_series_sub_type(::Type{ScenariosMetadata}, ::Type{Forecast}) = true

function check_resolution(ts::TimeSeries.TimeArray)
    error("TODO DT: we don't want this method")
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
        throw(
            DataFormatError(
                "time series has non-uniform resolution: this is currently not supported",
            ),
        )
    end

    return res[1]
end

"""
Check if the timestamps have a constant resolution.
Handles constant periods like Second and Minute as well as irregular periods like Month and Year.
Relies on the _calendrical_ arithmetic of the Julia's Dates library.
https://docs.julialang.org/en/v1/stdlib/Dates/#TimeType-Period-Arithmetic

# Arguments
- `timestamps`: An indexable sequence of DateTime values
- `resolution`: a Dates.Period value
"""
function check_resolution(timestamps, resolution::Dates.Period)
    # Note this behavior in Julia:
    # julia> DateTime("2020-02-01T00:00:00") + Month(1)
    # 2020-03-01T00:00:00
    for i in 2:length(timestamps)
        if timestamps[i] != timestamps[i - 1] + resolution
            throw(
                ConflictingInputsError(
                    "resolution mismatch: $timestamps[i - 1] $timestamps[i] $resolution",
                ),
            )
        end
    end
end

function get_initial_timestamp(data::TimeSeries.TimeArray)
    return TimeSeries.timestamp(data)[1]
end

function get_initial_times(
    initial_timestamp::Dates.DateTime,
    count::Int,
    interval::Dates.Period,
)
    if count == 0
        return []
    elseif interval == Dates.Second(0)
        return [initial_timestamp]
    end

    return range(initial_timestamp; length = count, step = interval)
end

"""
Given a series of timestamps that start with initial_time and increment by resolution,
return the index of other time in the array of timestamps.

# Examples
```julia
julia> compute_time_array_index(
    DateTime("2024-01-01T00:00:00"),
    DateTime("2024-01-01T05:00:00"),
    Hour(1),
)
6
julia> compute_time_array_index(
    DateTime("2024-01-01T00:00:00"),
    DateTime("2024-04-01T00:00:00"),
    Month(1),
)
4
julia> compute_time_array_index(
    DateTime("2024-01-01T00:00:00"),
    DateTime("2028-01-01T00:00:00"),
    Year(1),
)
5
```
"""
function compute_time_array_index(
    initial_time::Dates.DateTime,
    other_time::Dates.DateTime,
    resolution::Dates.Period,
)
    initial_time == other_time && return 1
    num_periods = compute_periods_between(initial_time, other_time, resolution)
    index = num_periods + 1
    return index
end

"""
Given a series of timestamps that increment by period, return the number of periods
between t1 and t2.

t2 must be greater than or equal to t1.
There must be an even number of periods between t1 and t2.
period can be regular (e.g., Hour) or irregular (e.g., Month).

# Arguments
- `t1`: The initial timestamp.
- `t2`: The second timestamp.
- `period`: The period to use for the index.

# Examples
```julia
julia> compute_periods_between(
    DateTime("2024-01-01T00:00:00"),
    DateTime("2024-01-01T05:00:00"),
    Hour(1),
)
5
julia> compute_period_index(
    DateTime("2024-02-01T00:00:00"),
    DateTime("2024-04-01T00:00:00"),
    Month(1),
)
2
julia> compute_period_index(
    DateTime("2024-01-01T00:00:00"),
    DateTime("2028-01-01T00:00:00"),
    Year(1),
)
4
```
"""
function compute_periods_between(
    t1::Dates.DateTime,
    t2::Dates.DateTime,
    period::Dates.Period,
)
    time_diff = t2 - t1
    return _compute_periods_between_common(t1, t2, period, time_diff, Dates.Millisecond(0))
end

function compute_periods_between(
    t1::Dates.DateTime,
    t2::Dates.DateTime,
    period::Dates.Month,
)
    year1, month1 = Dates.yearmonth(t1)
    year2, month2 = Dates.yearmonth(t2)
    time_diff = (year2 - year1) * 12 + (month2 - month1)
    return _compute_periods_between_common(t1, t2, Dates.value(period), time_diff, 0)
end

function compute_periods_between(
    t1::Dates.DateTime,
    t2::Dates.DateTime,
    period::Dates.Quarter,
)
    year1 = Dates.year(t1)
    quarter1 = Dates.quarter(t1)
    year2 = Dates.year(t2)
    quarter2 = Dates.quarter(t2)
    time_diff = (year2 - year1) * 4 + (quarter2 - quarter1)
    return _compute_periods_between_common(t1, t2, Dates.value(period), time_diff, 0)
end

function compute_periods_between(t1::Dates.DateTime, t2::Dates.DateTime, period::Dates.Year)
    time_diff = Dates.year(t2) - Dates.year(t1)
    return _compute_periods_between_common(t1, t2, Dates.value(period), time_diff, 0)
end

function _compute_periods_between_common(
    t1::Dates.DateTime,
    t2::Dates.DateTime,
    period,
    time_diff,
    zero_val,
)
    if t1 > t2
        throw(ArgumentError("t1 must be less than t2"))
    end

    if time_diff % period != zero_val
        throw(ArgumentError("$t2 - $t1 is not evenly divisible by $period"))
    end

    return time_diff ÷ period
end

"""
Return the resolution from a TimeArray.
"""
function get_resolution(ts::TimeSeries.TimeArray)
    if length(ts) < 2
        throw(ConflictingInputsError("Resolution can't be inferred from the data."))
    end

    timestamps = TimeSeries.timestamp(ts)
    return timestamps[2] - timestamps[1]
end

function get_total_period(
    initial_timestamp::Dates.DateTime,
    count::Int,
    interval::Dates.Period,
    horizon::Dates.Period,
    resolution::Dates.Period,
)
    horizon_count = get_horizon_count(horizon, resolution)
    last_it = initial_timestamp + interval * count
    last_timestamp = last_it + resolution * (horizon_count - 1)
    return last_timestamp - initial_timestamp
end

# These functions allow us to preserve type and value of periods in databases and files.
# We are not using string(period) because the Dates package behaves differently for
# singular vs plural and uses lower case. This is simpler.

to_string(period::Dates.Period) = "$(period.value) $(nameof(typeof(period)))"

function from_string(period::String)
    parts = split(period, " ")
    if length(parts) != 2
        throw(ArgumentError("Invalid period string: $period"))
    end

    value = parse(Int, parts[1])
    period_type = Symbol(parts[2])
    return getproperty(Dates, period_type)(value)
end

is_constant_period(period::Dates.Period) = true
is_constant_period(period::Dates.Month) = false
is_constant_period(period::Dates.Year) = false
is_constant_period(period::Dates.Quarter) = false
