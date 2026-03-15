"""
    TimeSeriesFunctionData <: FunctionData

Abstract supertype for `FunctionData` variants whose numerical data lives in a time series
rather than inline.

Each concrete subtype mirrors a static [`FunctionData`](@ref) subtype — same shape, but
instead of holding numbers directly, it holds a [`TimeSeriesKey`](@ref) that points to a
time series of the corresponding static type. Use these when cost function parameters change
at each simulation timestep (e.g., time-varying market offers).

Use [`is_time_series_backed`](@ref) to check at runtime, and [`get_time_series_key`](@ref)
to retrieve the key.
"""
abstract type TimeSeriesFunctionData <: FunctionData end

"""
    TimeSeriesLinearFunctionData <: TimeSeriesFunctionData

Time-series-backed variant of [`LinearFunctionData`](@ref). The `time_series_key`
references a time series whose elements are `LinearFunctionData`.
"""
@kwdef struct TimeSeriesLinearFunctionData <: TimeSeriesFunctionData
    time_series_key::TimeSeriesKey
end

"""
    TimeSeriesQuadraticFunctionData <: TimeSeriesFunctionData

Time-series-backed variant of [`QuadraticFunctionData`](@ref). The `time_series_key`
references a time series whose elements are `QuadraticFunctionData`.
"""
@kwdef struct TimeSeriesQuadraticFunctionData <: TimeSeriesFunctionData
    time_series_key::TimeSeriesKey
end

"""
    TimeSeriesPiecewiseLinearData <: TimeSeriesFunctionData

Time-series-backed variant of [`PiecewiseLinearData`](@ref). The `time_series_key`
references a time series whose elements are `PiecewiseLinearData`.
"""
@kwdef struct TimeSeriesPiecewiseLinearData <: TimeSeriesFunctionData
    time_series_key::TimeSeriesKey
end

"""
    TimeSeriesPiecewiseStepData <: TimeSeriesFunctionData

Time-series-backed variant of [`PiecewiseStepData`](@ref). The `time_series_key`
references a time series whose elements are `PiecewiseStepData`.
"""
@kwdef struct TimeSeriesPiecewiseStepData <: TimeSeriesFunctionData
    time_series_key::TimeSeriesKey
end

"""
    get_time_series_key(fd::TimeSeriesFunctionData) -> TimeSeriesKey

Return the `TimeSeriesKey` that references the underlying time series data.
"""
get_time_series_key(fd::TimeSeriesFunctionData) = fd.time_series_key

"""
    is_time_series_backed(fd::FunctionData) -> Bool

Return `true` if `fd` is a `TimeSeriesFunctionData` whose numerical values come
from a time series, `false` otherwise.
"""
is_time_series_backed(::FunctionData) = false
is_time_series_backed(::TimeSeriesFunctionData) = true

"""
    get_underlying_function_data_type(::Type{<:TimeSeriesFunctionData}) -> Type{<:FunctionData}

Return the concrete `FunctionData` type that the time series elements correspond to.
"""
function get_underlying_function_data_type end

get_underlying_function_data_type(::Type{TimeSeriesLinearFunctionData}) =
    LinearFunctionData
get_underlying_function_data_type(::Type{TimeSeriesQuadraticFunctionData}) =
    QuadraticFunctionData
get_underlying_function_data_type(::Type{TimeSeriesPiecewiseLinearData}) =
    PiecewiseLinearData
get_underlying_function_data_type(::Type{TimeSeriesPiecewiseStepData}) =
    PiecewiseStepData

# Instance convenience
get_underlying_function_data_type(fd::TimeSeriesFunctionData) =
    get_underlying_function_data_type(typeof(fd))

# Display
function Base.show(io::IO, ::MIME"text/plain", fd::TimeSeriesFunctionData)
    ts_key = get_time_series_key(fd)
    underlying = get_underlying_function_data_type(fd)
    print(
        io,
        "$(typeof(fd)) backed by time series \"$(get_name(ts_key))\" ",
        "of $underlying",
    )
end
