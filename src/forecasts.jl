"""
Supertype for forecast time series
Current concrete subtypes are:
- [`Deterministic`](@ref)
- [`DeterministicSingleTimeSeries`](@ref)
- [`Scenarios`](@ref)
- [`Probabilistic`](@ref)

Subtypes of Forecast must implement:
- `get_horizon_count`
- `get_initial_times`
- `get_initial_timestamp`
- `get_name`
- `get_scaling_factor_multiplier`
- `get_window`
- `iterate_windows`
"""
abstract type Forecast <: TimeSeriesData end

Base.length(ts::Forecast) = get_count(ts)

abstract type AbstractDeterministic <: Forecast end

function check_time_series_data(forecast::Forecast)
    _check_forecast_data(forecast)
    _check_forecast_interval(forecast)
    _check_forecast_windows(forecast)
end

function _check_forecast_data(forecast::Forecast)
    data = get_data(forecast)
    isempty(data) && throw(ArgumentError("Forecast data cannot be empty"))
    required_length = length(first(values(data)))
    required_length < 2 &&
        throw(ArgumentError("Forecast arrays must have a length of at least 2."))
    lengths = Set((length(x) for x in values(data)))
    length(lengths) != 1 &&
        throw(DimensionMismatch("All forecast arrays must have the same length"))
    return
end

function _check_forecast_interval(forecast::Forecast)
    # TODO DT: test a failure case. We haven't been checking consistency of intervals.
    check_resolution(collect(keys(get_data(forecast))), get_interval(forecast))
end

function _check_forecast_windows(forecast::Forecast)
    horizon_count = get_horizon_count(forecast)
    if horizon_count < 2
        throw(ArgumentError("horizon must be at least 2: $horizon_count"))
    end
    for window in iterate_windows(forecast)
        if size(window)[1] != horizon_count
            throw(
                ConflictingInputsError(
                    "length mismatch: $(size(window)[1]) $horizon_count",
                ),
            )
        end
    end
    return
end

# This method requires that the forecast type implement a `get_data` method like
# Deterministic.
function eltype_data_common(forecast::Forecast)
    return eltype(first(values(get_data(forecast))))
end

# This method requires that the forecast type implement a `get_data` method like
# Deterministic.
function get_count(forecast::Forecast)
    return length(get_data(forecast))
end

function get_horizon(forecast::Forecast)
    return get_horizon_count(forecast) * get_resolution(forecast)
end

"""
Return the initial times in the forecast.
"""
function get_initial_times(f::Forecast)
    return get_initial_times(get_initial_timestamp(f), get_count(f), get_interval(f))
end

# This method requires that the forecast type implement a `get_data` method like
# Deterministic. Allows for optimized execution.
function get_initial_times_common(forecast::Forecast)
    return keys(get_data(forecast))
end

"""
Return the total period covered by the forecast.
"""
function get_total_period(f::Forecast)
    return get_total_period(
        get_initial_timestamp(f),
        get_count(f),
        get_interval(f),
        get_horizon(f),
        get_resolution(f),
    )
end

function get_horizon_count(horizon::Dates.Period, resolution::Dates.Period)
    if horizon % resolution != Dates.Millisecond(0)
        error(
            "horizon is not evenly divisible by resolution: horizon = $horizon " *
            "resolution = $resolution",
        )
    end
    return horizon ÷ resolution
end

"""
Return the forecast window corresponsing to interval index.
"""
function get_window(forecast::Forecast, index::Int; len = nothing)
    return get_window(forecast, index_to_initial_time(forecast, index); len = len)
end

function iterate_windows_common(forecast)
    return (get_window(forecast, it) for it in keys(get_data(forecast)))
end

"""
Return the Dates.DateTime corresponding to an interval index.
"""
function index_to_initial_time(forecast::Forecast, index::Int)
    return get_initial_timestamp(forecast) + get_interval(forecast) * index
end

"""
Return a TimeSeries.TimeArray for one forecast window.
"""
function make_time_array(
    forecast::Forecast,
    start_time::Dates.DateTime;
    len::Union{Nothing, Int} = nothing,
)
    return get_window(forecast, start_time; len = len)
end

function make_timestamps(forecast::Forecast, initial_time::Dates.DateTime, len = nothing)
    if isnothing(len)
        len = get_horizon_count(forecast)
    end

    return range(initial_time; length = len, step = get_resolution(forecast))
end

# This method requires that the forecast type implement a `get_data` method like
# Deterministic. Allows for optimized execution.
function get_initial_timestamp_common(forecast)
    return first(keys(get_data(forecast)))
end

# This method requires that the forecast type implement a `get_data` method like
# Deterministic. Allows for optimized execution.
function get_interval_common(forecast)
    its = get_initial_times(forecast)
    if length(its) == 1
        return Dates.Second(0)
    end
    first_it, state = iterate(its)
    second_it, state = iterate(its, state)
    return second_it - first_it
end

# This method requires that the forecast type implement a `get_data` method like
# Deterministic.
function get_window_common(
    forecast,
    initial_time::Dates.DateTime;
    len::Union{Nothing, Int} = nothing,
)
    horizon_count = get_horizon_count(forecast)
    if isnothing(len)
        len = horizon_count
    end

    data = get_data(forecast)[initial_time]
    if ndims(data) == 2
        # This is necessary because the Deterministic and Probabilistic are 3D Arrays
        # We need to do this to make the data a 2D TimeArray. In a get_window the data is always count = 1
        @assert_op size(data)[1] <= len
        data = @view data[1:len, :]
    else
        data = @view data[1:len]
    end

    return TimeSeries.TimeArray(make_timestamps(forecast, initial_time, len), data)
end
