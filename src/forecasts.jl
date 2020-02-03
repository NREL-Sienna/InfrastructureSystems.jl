
"""
Abstract type for forecasts that are stored in a system.
Users never create them or get access to them.
Stores references to time series data, so a disk read may be required for access.
"""
abstract type ForecastInternal <: InfrastructureSystemsType end

"""
Abstract type for forecasts supplied to users. They are not stored in a system. Instead,
they are generated on demand for the user.
Users can create them. The system will convert them to a subtype of ForecastInternal for 
storage.
Time series data is stored as a field, so reads will always be from memory.
"""
abstract type Forecast <: Any end

get_horizon(forecast::Forecast) = length(get_data(forecast))
get_initial_time(forecast::Forecast) = TimeSeries.timestamp(get_data(forecast))[1]
get_scaling_factors(forecast::Forecast) = get_data(forecast)

function get_resolution(forecast::Forecast)
    data = get_data(forecast)
    return TimeSeries.timestamp(data)[2] - TimeSeries.timestamp(data)[1]
end

struct ForecastKey
    forecast_type::Type{<:ForecastInternal}
    initial_time::Dates.DateTime
    label::String
end

const ForecastsByType = Dict{ForecastKey, ForecastInternal}

"""
Forecast container for a component.
"""
mutable struct Forecasts
    data::ForecastsByType
    time_series_storage::Union{Nothing, TimeSeriesStorage}
end

function Forecasts()
    return Forecasts(ForecastsByType(), nothing)
end

Base.length(forecasts::Forecasts) = length(forecasts.data)
Base.isempty(forecasts::Forecasts) = isempty(forecasts.data)

function set_time_series_storage!(
    forecasts::Forecasts,
    storage::Union{Nothing, TimeSeriesStorage},
)
    if !isnothing(forecasts.time_series_storage) && !isnothing(storage)
        @show forecasts.time_series_storage
        throw(ArgumentError(
            "The time_series_storage reference is already set. Is this component being " *
            "added to multiple systems?",
        ))
    end

    forecasts.time_series_storage = storage
end

function add_forecast!(forecasts::Forecasts, forecast::T) where {T <: ForecastInternal}
    key = ForecastKey(T, get_initial_time(forecast), get_label(forecast))
    if haskey(forecasts.data, key)
        throw(ArgumentError("forecast $key is already stored"))
    end

    forecasts.data[key] = forecast
end

function remove_forecast!(
    ::Type{T},
    forecasts::Forecasts,
    initial_time::Dates.DateTime,
    label::AbstractString,
) where {T <: ForecastInternal}
    key = ForecastKey(T, initial_time, label)
    if !haskey(forecasts.data, key)
        throw(ArgumentError("forecast $key is not stored"))
    end

    pop!(forecasts.data, key)
end

function clear_forecasts!(forecasts::Forecasts)
    empty!(forecasts.data)
end

function get_forecast(
    ::Type{T},
    forecasts::Forecasts,
    initial_time::Dates.DateTime,
    label::AbstractString,
) where {T <: ForecastInternal}
    key = ForecastKey(T, initial_time, label)
    if !haskey(forecasts.data, key)
        throw(ArgumentError("forecast $key is not stored"))
    end

    return forecasts.data[key]
end

function get_forecast_initial_times(forecasts::Forecasts)::Vector{Dates.DateTime}
    initial_times = Set{Dates.DateTime}()
    for key in keys(forecasts.data)
        push!(initial_times, key.initial_time)
    end

    return sort!(Vector{Dates.DateTime}(collect(initial_times)))
end

function get_forecast_initial_times(
    ::Type{T},
    forecasts::Forecasts,
) where {T <: ForecastInternal}
    initial_times = Set{Dates.DateTime}()
    for key in keys(forecasts.data)
        if key.forecast_type <: T
            push!(initial_times, key.initial_time)
        end
    end

    return sort!(Vector{Dates.DateTime}(collect(initial_times)))
end

function get_forecast_initial_times(
    ::Type{T},
    forecasts::Forecasts,
    label::AbstractString,
) where {T <: ForecastInternal}
    initial_times = Set{Dates.DateTime}()
    for key in keys(forecasts.data)
        if key.forecast_type <: T && key.label == label
            push!(initial_times, key.initial_time)
        end
    end

    return sort!(Vector{Dates.DateTime}(collect(initial_times)))
end

function get_forecast_initial_times!(
    initial_times::Set{Dates.DateTime},
    forecasts::Forecasts,
)
    for key in keys(forecasts.data)
        push!(initial_times, key.initial_time)
    end
end

function get_forecast_labels(
    ::Type{T},
    forecasts::Forecasts,
    initial_time::Dates.DateTime,
) where {T <: ForecastInternal}
    labels = Set{String}()
    for key in keys(forecasts.data)
        if key.forecast_type <: T && key.initial_time == initial_time
            push!(labels, key.label)
        end
    end

    return Vector{String}(collect(labels))
end

struct ForecastSerializationWrapper
    forecast::ForecastInternal
    type::DataType
end

function JSON2.write(io::IO, forecasts::Forecasts)
    return JSON2.write(io, encode_for_json(forecasts))
end

function JSON2.write(forecasts::Forecasts)
    return JSON2.write(encode_for_json(forecasts))
end

function encode_for_json(forecasts::Forecasts)
    # Store a flat array of forecasts. Deserialization can unwind it.
    data = Vector{ForecastSerializationWrapper}()
    for (key, forecast) in forecasts.data
        push!(data, ForecastSerializationWrapper(forecast, key.forecast_type))
    end

    return data
end

function JSON2.read(io::IO, ::Type{Forecasts})
    forecasts = Forecasts()
    for raw_forecast in JSON2.read(io)
        forecast_type = getfield(
            InfrastructureSystems,
            Symbol(strip_module_name(string(raw_forecast.type))),
        )
        forecast = JSON2.read(JSON2.write(raw_forecast.forecast), forecast_type)
        add_forecast!(forecasts, forecast)
    end

    return forecasts
end

function Base.length(forecast::Forecast)
    return get_horizon(forecast)
end

function Base.getindex(forecast::Forecast, args...)
    return _split_forecast(forecast, getindex(get_data(forecast), args...))
end

Base.first(forecast::Forecast) = head(forecast, 1)

Base.last(forecast::Forecast) = tail(forecast, 1)

Base.firstindex(forecast::Forecast) = firstindex(get_data(forecast))

Base.lastindex(forecast::Forecast) = lastindex(get_data(forecast))

Base.lastindex(forecast::Forecast, d) = lastindex(get_data(forecast), d)

Base.eachindex(forecast::Forecast) = eachindex(get_data(forecast))

Base.iterate(forecast::Forecast, n = 1) = iterate(get_data(forecast), n)

"""
    when(forecast::Forecast, period::Function, t::Integer)

Refer to TimeSeries.when(). Underlying data is copied.
"""
function when(forecast::Forecast, period::Function, t::Integer)
    new = _split_forecast(forecast, TimeSeries.when(get_data(forecast), period, t))

end

"""
    from(forecast::Forecast, timestamp)

Return a forecast truncated starting with timestamp.
"""
function from(forecast::T, timestamp) where {T <: Forecast}
    return T(get_label(forecast), TimeSeries.from(get_data(forecast), timestamp))
end

"""
    to(forecast::Forecast, timestamp)

Return a forecast truncated after timestamp.
"""
function to(forecast::T, timestamp) where {T <: Forecast}
    return T(get_label(forecast), TimeSeries.to(get_data(forecast), timestamp))
end

"""
    head(forecast::Forecast)
    head(forecast::Forecast, num)

Return a forecast with only the first num values.
"""
function head(forecast::Forecast)
    return _split_forecast(forecast, TimeSeries.head(get_data(forecast)))
end

function head(forecast::Forecast, num)
    return _split_forecast(forecast, TimeSeries.head(get_data(forecast), num))
end

"""
    tail(forecast::Forecast)
    tail(forecast::Forecast, num)

Return a forecast with only the ending num values.
"""
function tail(forecast::Forecast)
    return _split_forecast(forecast, TimeSeries.tail(get_data(forecast)))
end

function tail(forecast::Forecast, num)
    return _split_forecast(forecast, TimeSeries.tail(get_data(forecast), num))
end

"""
Creates a new forecast from an existing forecast with a split TimeArray.
"""
function

_split_forecast(forecast::T, data::TimeSeries.TimeArray;) where {T <: Forecast}
    vals = []
    for (fname, ftype) in zip(fieldnames(T), fieldtypes(T))
        if ftype <: TimeSeries.TimeArray
            val = data
        elseif ftype <: InfrastructureSystemsInternal
            # Need to create a new UUID.
            continue
        else
            val = getfield(forecast, fname)
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
            throw(DataFormatError("cannot understand the resolution of the timeseries"))
        end
    end

    if length(res) > 1
        throw(DataFormatError("timeseries has non-uniform resolution: this is currently not supported"))
    end

    return res[1]
end
