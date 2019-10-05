
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
get_time_series(forecast::Forecast) = get_data(forecast)

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
    resolution::Dates.Period
    horizon::Int64
end

function Forecasts()
    return Forecasts(ForecastsByType(), UNINITIALIZED_PERIOD, UNINITIALIZED_HORIZON)
end

function add_forecast!(forecasts::Forecasts, forecast::T) where T <: ForecastInternal
    key = ForecastKey(T, get_initial_time(forecast), get_label(forecast))
    if haskey(forecasts.data, key)
        throw(ArgumentError("forecast $key is already stored"))
    end

    forecasts.data[key] = forecast
end

# TODO DT: not sure if this should be Forecast  or ForecastInternal
# It's possible that a user calls remove_forecast!(sys, forecast::Forecast) when that
# forecast is a segment of a larger ForecastInternal.
# Deletes with Forecast should only be allowed on a non-split.
#function remove_forecast!(forecasts::Forecasts, forecast::T) where T <: ForecastInternal
#    key = ForecastKey(T, get_initial_time(forecast), get_label(forecast))
#    if !haskey(forecasts.data, key)
#        throw(ArgumentError("forecast $key is not stored"))
#    end
#
#    pop!(forecasts.data, key)
#end

function clear_forecasts!(forecasts::Forecasts)
    empty!(forecasts.data)
end

function get_forecast(
                      ::Type{T},
                      forecasts::Forecasts,
                      initial_time::Dates.DateTime,
                      label::AbstractString,
                     ) where T <: ForecastInternal
    key = ForecastKey(T, initial_time, label)
    if !haskey(forecasts.data, key)
        throw(ArgumentError("forecast $key is not stored"))
    end

    return forecasts.data[key]
end

#function get_forecasts(
#                       ::Type{T},
#                       forecasts::Forecasts,
#                       initial_time::Dates.DateTime,
#                       label::AbstractString,
#                      ) where T <: ForecastInternal
#    return [forecast for (key, forecast) in forecasts.data
#            if key.initial_time == initial_time && key.forecast_type <: T]
#end

function get_forecast_initial_times(forecasts::Forecasts)::Vector{Dates.DateTime}
    initial_times = Set{Dates.DateTime}()
    for key in keys(forecasts.data)
        push!(initial_times, key.initial_time)
    end

    return sort!(Vector{Dates.DateTime}(collect(initial_times)))
end

function get_forecast_initial_times(::Type{T}, forecasts::Forecasts) where T <: ForecastInternal
    initial_times = Set{Dates.DateTime}()
    for key in keys(forecasts.data)
        if key.forecast_type <: T
            push!(initial_times, key.initial_time)
        end
    end

    return sort!(Vector{Dates.DateTime}(collect(initial_times)))
end

function get_forecast_initial_times(::Type{T}, forecasts::Forecasts, label::AbstractString) where T <: ForecastInternal
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

function get_forecast_labels(::Type{T}, forecasts::Forecasts, initial_time::Dates.DateTime) where T <: ForecastInternal
    labels = Set{String}()
    for key in keys(forecasts.data)
        if key.forecast_type <: T && key.initial_time == initial_time
            push!(labels, key.label)
        end
    end

    return Vector{String}(collect(labels))
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

Return a forecast truncated starting with timestamp. Underlying data is not copied.
"""
function from(forecast::Forecast, timestamp)
    return TimeSeries.from(get_data(forecast), timestamp)
    ## Don't use TimeSeries.from because it makes a copy.
    #start_index = 1
    #end_index = start_index + get_horizon(forecast)
    #for i in 1 : end_index
    #    if TimeSeries.timestamp(get_data(forecast))[i] >= timestamp
    #        fcast = _split_forecast(forecast, get_data(forecast); is_copy=false)
    #        fcast.start_index = i
    #        fcast.horizon = end_index - i
    #        return fcast
    #    end
    #end

    ## Do whatever TimeSeries does if the timestamp is after the forecast.
    #return _split_forecast(forecast, TimeSeries.from(get_data(forecast), timestamp))
end

"""
    to(forecast::Forecast, timestamp)

Return a forecast truncated after timestamp. Underlying data is not copied.
"""
function to(forecast::Forecast, timestamp)
    return TimeSeries.to(get_data(forecast), timestamp)

    ## Don't use TimeSeries.from because it makes a copy.
    #start_index = get_start_index(forecast)
    #end_index = start_index + get_horizon(forecast)
    #for i in get_start_index(forecast) : end_index
    #    tstamp = TimeSeries.timestamp(get_data(forecast))[i]
    #    if tstamp < timestamp
    #        continue
    #    elseif tstamp == timestamp
    #        end_index = i
    #    else
    #        @assert tstamp > timestamp
    #        end_index = i - 1
    #    end

    #    fcast = _split_forecast(forecast, get_data(forecast); is_copy=false)
    #    fcast.horizon = end_index - start_index + 1
    #    return fcast
    #end

    ## Do whatever TimeSeries does if the timestamp is after the forecast.
    #return _split_forecast(forecast, TimeSeries.to(get_data(forecast), timestamp))
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

# Arguments
- `is_copy::Bool=true`: Reset internal indices because the TimeArray is a fresh copy.
"""
function _split_forecast(
                         forecast::T,
                         data::TimeSeries.TimeArray;
                         #is_copy=true,
                        ) where T <: Forecast
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

    new_forecast = T(vals...)
    #if is_copy
    #    new_forecast.horizon = length(get_data(new_forecast))
    #end
    return new_forecast
end

