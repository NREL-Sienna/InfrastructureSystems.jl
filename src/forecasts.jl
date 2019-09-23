abstract type Forecast <: InfrastructureSystemsType end

const ForecastComponentLabelPair = Tuple{<:InfrastructureSystemsType, String}
const ForecastComponentLabelPairByInitialTime = Dict{Dates.DateTime,
                                                     Set{ForecastComponentLabelPair}}
const UNITIALIZED_DATETIME = Dates.DateTime(Dates.Minute(0))
const UNITIALIZED_PERIOD = Dates.Period(Dates.Minute(0))
const UNITIALIZED_HORIZON = 0



function get_component(forecast::Forecast)
    return forecast.component
end

struct ForecastKey
    initial_time::Dates.DateTime
    forecast_type::DataType
end

const ForecastsByType = Dict{ForecastKey, Vector{<:Forecast}}

function _get_forecast_initial_times(data::ForecastsByType)::Vector{Dates.DateTime}
    initial_times = Set{Dates.DateTime}()
    for key in keys(data)
        push!(initial_times, key.initial_time)
    end

    return sort!(Vector{Dates.DateTime}(collect(initial_times)))
end

function _verify_forecasts!(
                            unique_components::ForecastComponentLabelPairByInitialTime,
                            data::ForecastsByType,
                            forecast::T,
                           ) where T <: Forecast
    key = ForecastKey(forecast.initial_time, T)
    component_label = (forecast.component, forecast.label)

    if !haskey(unique_components, forecast.initial_time)
        unique_components[forecast.initial_time] = Set{ForecastComponentLabelPair}()
    end

    if haskey(data, key) && component_label in unique_components[forecast.initial_time]
        throw(DataFormatError(
            "forecast component-label pairs is not unique within forecasts; " *
            "label=$component_label initial_time=$(forecast.initial_time)"
        ))
    end

    push!(unique_components[forecast.initial_time], component_label)
end

function _add_forecast!(data::ForecastsByType, forecast::T) where T <: Forecast
    key = ForecastKey(forecast.initial_time, T)
    if !haskey(data, key)
        data[key] = Vector{T}()
    end

    push!(data[key], forecast)
end

"""Container for forecasts and their metadata.."""
mutable struct Forecasts
    data::ForecastsByType
    initial_time::Dates.DateTime
    resolution::Dates.Period
    horizon::Int64
    interval::Dates.Period
end

function Forecasts()
    forecasts_by_type = ForecastsByType()
    initial_time = UNITIALIZED_DATETIME
    resolution = UNITIALIZED_PERIOD
    horizon = UNITIALIZED_HORIZON
    interval = UNITIALIZED_PERIOD

    return Forecasts(forecasts_by_type, initial_time, resolution, horizon, interval)
end

"""Iterates over all forecasts in order of initial time.

# Examples
```julia
for forecast in iterate_forecasts(forecasts)
    @show forecast
end
```

See also: [`get_forecasts`](@ref)
"""
function iterate_forecasts(forecasts::Forecasts)
    Channel() do channel
        for initial_time in get_forecast_initial_times(forecasts)
            for forecast in get_forecasts(Forecast, forecasts, initial_time)
                put!(channel, forecast)
            end
        end
    end
end

function reset_info!(forecasts::Forecasts)
    forecasts.initial_time = UNITIALIZED_DATETIME
    forecasts.resolution = UNITIALIZED_PERIOD
    forecasts.horizon = UNITIALIZED_HORIZON
    @info "Reset system forecast information."
end

function is_uninitialized(forecasts::Forecasts)
    return forecasts.initial_time == UNITIALIZED_DATETIME &&
           forecasts.resolution == UNITIALIZED_PERIOD &&
           forecasts.horizon == UNITIALIZED_HORIZON
end

function _verify_forecasts(forecasts::Forecasts, forecasts_)
    # Collect all existing component labels.
    unique_components = ForecastComponentLabelPairByInitialTime()
    for (key, existing_forecasts) in forecasts.data
        for forecast in existing_forecasts
            if !haskey(unique_components, forecast.initial_time)
                unique_components[forecast.initial_time] = Set{ForecastComponentLabelPair}()
            end

            component_label = (forecast.component, forecast.label)
            push!(unique_components[forecast.initial_time], component_label)
        end
    end

    for forecast in forecasts_
        if forecast.resolution != forecasts.resolution
            throw(DataFormatError(
                "Forecast resolution $(forecast.resolution) does not match system " *
                "resolution $(forecasts.resolution)"
            ))
        end

        if get_horizon(forecast) != forecasts.horizon
            throw(DataFormatError(
                "Forecast horizon $(get_horizon(forecast)) does not match system horizon " *
                "$(forecasts.horizon)"
            ))
        end

        _verify_forecasts!(unique_components, forecasts.data, forecast)
    end
end

function _add_forecasts!(forecasts::Forecasts, forecasts_)
    if length(forecasts_) == 0
        return
    end

    if is_uninitialized(forecasts)
        # This is the first forecast added.
        forecast = iterate(forecasts_)[1]
        forecasts.horizon = get_horizon(forecast)
        forecasts.resolution = forecast.resolution
        forecasts.initial_time = forecast.initial_time
    end

    # Adding forecasts is all-or-none. Loop once to validate and then again to add them.
    # This will throw if something is invalid.
    _verify_forecasts(forecasts, forecasts_)

    for forecast in forecasts_
        _add_forecast!(forecasts.data, forecast)
    end

    set_interval!(forecasts)
end

function set_interval!(forecasts::Forecasts)
    initial_times = _get_forecast_initial_times(forecasts.data)
    if length(initial_times) == 1
        # TODO this needs work
        forecasts.interval = forecasts.resolution
    elseif length(initial_times) > 1
        # TODO is this correct?
        forecasts.interval = initial_times[2] - initial_times[1]
    else
        @error "no forecasts detected" forecasts maxlog=1
        forecasts.interval = Dates.Day(1)  # TODO
        #throw(DataFormatError("no forecasts detected"))
    end
end

"""Partially constructs Forecasts from JSON. Forecasts are not constructed."""
function Forecasts(data::NamedTuple)
    initial_time = Dates.DateTime(data.initial_time)
    resolution = JSON2.read(JSON2.write(data.resolution), Dates.Period)
    horizon = data.horizon
    interval = JSON2.read(JSON2.write(data.interval), Dates.Period)

    return Forecasts(ForecastsByType(), initial_time, resolution, horizon, interval)
end

"""
    get_component_forecasts(
                            ::Type{T},
                            forecasts::Forecasts,
                            initial_time::Dates.DateTime,
                           ) where T <: InfrastructureSystemsType

Get the forecasts of a component of type T with initial_time.
The resulting container can contain Forecasts of dissimilar types.

Throws ArgumentError if T is not a concrete type.

See also: [`get_component`](@ref)
"""
function get_component_forecasts(
                                 ::Type{T},
                                 forecasts::Forecasts,
                                 initial_time::Dates.DateTime,
                                ) where T <: InfrastructureSystemsType
    if !isconcretetype(T)
        throw(ArgumentError("get_component_forecasts only supports concrete types: $T"))
    end

    return (f for k in keys(forecasts.data) if k.initial_time == initial_time
              for f in forecasts.data[k] if isa(get_component(f), T))
end

"""Return the horizon for all forecasts."""
get_forecasts_horizon(forecasts::Forecasts)::Int64 = forecasts.horizon

"""Return the earliest initial_time for a forecast."""
get_forecasts_initial_time(forecasts::Forecasts)::Dates.DateTime = forecasts.initial_time

"""Return the interval for all forecasts."""
get_forecasts_interval(forecasts::Forecasts)::Dates.Period = forecasts.interval

"""Return the resolution for all forecasts."""
get_forecasts_resolution(forecasts::Forecasts)::Dates.Period = forecasts.resolution

"""
    get_forecast_initial_times(forecasts::Forecasts)::Vector{Dates.DateTime}

Return sorted forecast initial times.

"""
function get_forecast_initial_times(forecasts::Forecasts)::Vector{Dates.DateTime}
    return _get_forecast_initial_times(forecasts.data)
end

"""
    get_forecasts(::Type{T}, forecasts::Forecasts, initial_time::Dates.DateTime)

Return an iterator of forecasts. T can be concrete or abstract.

Call collect on the result if an array is desired.

This method is fast and efficient because it returns an iterator to existing vectors.

# Examples
```julia
iter = PowerSystems.get_forecasts(Deterministic{RenewableFix}, forecasts, initial_time)
iter = PowerSystems.get_forecasts(Forecast, forecasts, initial_time)
forecasts = PowerSystems.get_forecasts(Forecast, forecasts, initial_time) |> collect
forecasts = collect(PowerSystems.get_forecasts(Forecast, forecasts))
```

See also: [`iterate_forecasts`](@ref)
"""
function get_forecasts(
                       ::Type{T},
                       forecasts::Forecasts,
                       initial_time::Dates.DateTime,
                      )::FlattenIteratorWrapper{T} where T <: Forecast
    if isconcretetype(T)
        key = ForecastKey(initial_time, T)
        forecasts = get(forecasts.data, key, nothing)
        if isnothing(forecasts)
            iter = FlattenIteratorWrapper(T, Vector{Vector{T}}([]))
        else
            iter = FlattenIteratorWrapper(T, Vector{Vector{T}}([forecasts]))
        end
    else
        keys_ = [ForecastKey(initial_time, x.forecast_type)
                 for x in keys(forecasts.data) if x.initial_time == initial_time &&
                                                      x.forecast_type <: T]
        iter = FlattenIteratorWrapper(T, Vector{Vector{T}}([forecasts.data[x]
                                                            for x in keys_]))
    end

    @assert eltype(iter) == T
    return iter
end

"""
    get_forecasts(
                  ::Type{T},
                  forecasts::Forecasts,
                  initial_time::Dates.DateTime,
                  components_iterator,
                  label::Union{String, Nothing}=nothing,
                 )::Vector{Forecast}

# Arguments
- `forecasts::Forecasts`: system
- `initial_time::Dates.DateTime`: time designator for the forecast
- `components_iter`: iterable (array, iterator, etc.) of Component values
- `label::Union{String, Nothing}`: forecast label or nothing

Return forecasts that match the components and label.

This method is slower than the first version because it has to compare components and label
as well as build a new vector.

Throws ArgumentError if eltype(components_iterator) is a concrete type and no forecast is
found for a component.
"""
function get_forecasts(
                       ::Type{T},
                       forecasts::Forecasts,
                       initial_time::Dates.DateTime,
                       components_iterator,
                       label::Union{String, Nothing}=nothing,
                      )::Vector{T} where T <: Forecast
    forecasts_ = Vector{T}()
    elem_type = eltype(components_iterator)
    throw_on_unmatched_component = isconcretetype(elem_type)
    @debug "get_forecasts" initial_time label elem_type throw_on_unmatched_component

    # Cache the component UUIDs and matched component UUIDs so that we iterate over
    # components_iterator and forecasts only once.
    components = Set{Base.UUID}((get_uuid(x) for x in components_iterator))
    matched_components = Set{Base.UUID}()
    for forecast in get_forecasts(T, forecasts, initial_time)
        if !isnothing(label) && label != forecast.label
            continue
        end

        component_uuid = get_uuid(forecast.component)
        if in(component_uuid, components)
            push!(forecasts_, forecast)
            push!(matched_components, component_uuid)
        end
    end

    if length(components) != length(matched_components)
        unmatched_components = setdiff(components, matched_components)
        @warn "Did not find forecasts with UUIDs" unmatched_components
        if throw_on_unmatched_component
            throw(ArgumentError("did not find forecasts for one or more components"))
        end
    end

    return forecasts_
end

"""
    get_forecasts(
                  forecasts::Forecasts,
                  initial_time::Dates.DateTime,
                  components_iterator,
                  label::Union{String, Nothing}=nothing,
                 )

# Arguments
- `forecasts::Forecasts`: system
- `initial_time::Dates.DateTime`: time designator for the forecast
- `components_iter`: iterable (array, iterator, etc.) of Component values
- `label::Union{String, Nothing}`: forecast label or nothing

Return forecasts of any type <: Forecast that match the components and label.

This method is slower than the first version because it has to compare components and label
as well as build a new vector.

Throws ArgumentError if eltype(components_iterator) is a concrete type and no forecast is
found for a component.
"""
function get_forecasts(forecasts::Forecasts,
                       initial_time::Dates.DateTime,
                       components_iterator,
                       label::Union{String, Nothing}=nothing,
                      )

    return get_forecasts(Forecast,
                         forecasts,
                         initial_time,
                         components_iterator,
                         label)
end

"""
    remove_forecast(forecasts::Forecasts, forecast::Forecast)

Remove the forecast from the system.

Throws ArgumentError if the forecast is not stored.
"""
function remove_forecast!(forecasts::Forecasts, forecast::T) where T <: Forecast
    key = ForecastKey(forecast.initial_time, T)

    if !haskey(forecasts.data, key)
        throw(ArgumentError("Forecast not found: $(forecast.label)"))
    end

    found = false
    for (i, forecast) in enumerate(forecasts.data[key])
        if get_uuid(forecast) == get_uuid(forecast)
            found = true
            deleteat!(forecasts.data[key], i)
            @info "Deleted forecast $(get_uuid(forecast))"
            if length(forecasts.data[key]) == 0
                pop!(forecasts.data, key)
            end
            break
        end
    end

    if !found
        throw(ArgumentError("Forecast not found: $(forecast.label)"))
    end

    if length(forecasts.data) == 0
        reset_info!(forecasts)
    end
end

"""
    clear_forecasts!(forecasts::Forecasts)

Remove all forecast objects from a Forecasts
"""
function clear_forecasts!(forecasts::Forecasts)
    empty!(forecasts.data)
    reset_info!(forecasts)
    return
end

function get_num_forecasts(forecasts::Forecasts)
    count = 0
    for forecasts in values(forecasts.data)
        count += length(forecasts)
    end
    return count
end

function JSON2.write(io::IO, forecasts::Forecasts)
    return JSON2.write(io, encode_for_json(forecasts))
end

function JSON2.write(forecasts::Forecasts)
    return JSON2.write(encode_for_json(forecasts))
end

function encode_for_json(forecasts::Forecasts)
    # Many forecasts could have references to the same timeseries data, so we want to
    # avoid writing out duplicates.  Here's the flow:
    # 1. Identify duplicates by creating a hash of each.
    # 2. Create one UUID for each unique timeseries.
    # 3. Identify all forecast UUIDs that share each timeseries.
    # 4. Write out a vector of TimeseriesSerializationInfo items.
    # 5. Deserializion can re-create everything from this info.

    hash_to_uuid = Dict{UInt64, Base.UUID}()
    uuid_to_timeseries = Dict{Base.UUID, TimeseriesSerializationInfo}()

    for forecasts in values(forecasts.data)
        for forecast in forecasts
            hash_value = hash(forecast.data)
            if !haskey(hash_to_uuid, hash_value)
                uuid = UUIDs.uuid4()
                hash_to_uuid[hash_value] = uuid
                uuid_to_timeseries[uuid] = TimeseriesSerializationInfo(uuid,
                                                                       forecast.data,
                                                                       [get_uuid(forecast)])
            else
                uuid = hash_to_uuid[hash_value]
                push!(uuid_to_timeseries[uuid].forecasts, get_uuid(forecast))
            end
        end
    end

    # This procedure forces us to handle all fields manually, so assert that we have them
    # all covered in case someone adds a field later.
    fields = (:data, :initial_time, :resolution, :horizon, :interval)
    @assert fields == fieldnames(Forecasts)

    data = Dict()
    for field in fields
        field == :data && continue
        data[string(field)] = getfield(forecasts, field)
    end

    # Make a flat array of forecasts regardless of ForecastKey.
    # Deserialization can re-create the existing structure.
    data["forecasts"] = [x for (k, v) in forecasts.data for x in v]

    data["timeseries_infos"] = collect(values(uuid_to_timeseries))
    return data
end

struct TimeseriesSerializationInfo
    timeseries_uuid::Base.UUID
    timeseries::TimeSeries.TimeArray
    forecasts::Vector{Base.UUID}
end

"""Converts forecast JSON data to Forecasts."""
function convert_type!(
                       forecasts::Forecasts,
                       raw::NamedTuple,
                       component_cache::Dict,
                      ) where T <: Forecast
    for field in (:initial_time, :resolution, :horizon, :interval)
        field_type = fieldtype(typeof(forecasts), field)
        val = getproperty(raw, field)
        setfield!(forecasts, field, convert_type(field_type, val))
    end

    forecast_uuid_to_timeseries = Dict{Base.UUID, TimeSeries.TimeArray}()

    for val in raw.timeseries_infos
        timeseries_info = convert_type(TimeseriesSerializationInfo, val)
        for forecast_uuid in timeseries_info.forecasts
            @assert !haskey(forecast_uuid_to_timeseries, forecast_uuid)
            forecast_uuid_to_timeseries[forecast_uuid] = timeseries_info.timeseries
        end
    end

    forecasts_ = Vector{Forecast}()
    for forecast in raw.forecasts
        uuid = Base.UUID(forecast.internal.uuid.value)
        if !haskey(forecast_uuid_to_timeseries, uuid)
            throw(DataFormatError("unmatched timeseries UUID: $uuid $forecast"))
        end
        timeseries = forecast_uuid_to_timeseries[uuid]
        forecast_base_type = getfield(InfrastructureSystems,
                                      Symbol(strip_module_name(string(forecast.type))))
        val = convert_type(forecast_base_type, forecast, component_cache, timeseries)
        push!(forecasts_, val)
    end

    _add_forecasts!(forecasts, forecasts_)
end

function Base.length(forecast::Forecast)
    return get_horizon(forecast)
end

"""
    get_timeseries(forecast::Forecast)

Return the timeseries for the forecast.

Note: timeseries data is stored in TimeSeries.TimeArray objects. TimeArray does not
currently support Base.view, so calling this function results in a memory allocation and
copy. Tracked in https://github.com/JuliaStats/TimeSeries.jl/issues/419.
"""
function get_timeseries(forecast::Forecast)
    full_ts = get_data(forecast)
    start_index = get_start_index(forecast)
    end_index = start_index + get_horizon(forecast) - 1
    return full_ts[start_index:end_index]
end

"""
    make_forecasts(forecast::FlattenIteratorWrapper{T},
                    interval::Dates.Period, horizon::Int) where T <: Forecast

Make an iterator of forecasts by incrementing through a vector of forecasts
by interval and horizon.
"""
function make_forecasts(
                        forecast::FlattenIteratorWrapper{T},
                        interval::Dates.Period,
                        horizon::Int,
                       ) where T <: Forecast

    forecasts = [make_forecasts(f, interval, horizon) for f in forecast]

    return FlattenIteratorWrapper(T, forecasts)
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
        throw(DataFormatError(
            "timeseries has non-uniform resolution: this is currently not supported"
        ))
    end

    return res[1]
end

"""
Creates a new forecast from an existing forecast with a split TimeArray.

# Arguments
- `is_copy::Bool=true`: Reset internal indices because the TimeArray is a fresh copy.
"""
function _split_forecast(
                         forecast::T,
                         data::TimeSeries.TimeArray;
                         is_copy=true,
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
    if is_copy
        new_forecast.start_index = 1
        new_forecast.horizon = length(get_data(new_forecast))
    end
    return new_forecast
end

function Base.getindex(forecast::Forecast, args...)
    return _split_forecast(forecast, getindex(get_timeseries(forecast), args...))
end

Base.first(forecast::Forecast) = head(forecast, 1)

Base.last(forecast::Forecast) = tail(forecast, 1)

Base.firstindex(forecast::Forecast) = firstindex(get_timeseries(forecast))

Base.lastindex(forecast::Forecast) = lastindex(get_timeseries(forecast))

Base.lastindex(forecast::Forecast, d) = lastindex(get_timeseries(forecast), d)

Base.eachindex(forecast::Forecast) = eachindex(get_timeseries(forecast))

Base.iterate(forecast::Forecast, n = 1) = iterate(get_timeseries(forecast), n)

"""
    when(forecast::Forecast, period::Function, t::Integer)

Refer to TimeSeries.when(). Underlying data is copied.
"""
function when(forecast::Forecast, period::Function, t::Integer)
    new = _split_forecast(forecast, TimeSeries.when(get_timeseries(forecast), period, t))

end

"""
    from(forecast::Forecast, timestamp)

Return a forecast truncated starting with timestamp. Underlying data is not copied.
"""
function from(forecast::Forecast, timestamp)
    # Don't use TimeSeries.from because it makes a copy.
    start_index = get_start_index(forecast)
    end_index = start_index + get_horizon(forecast)
    for i in get_start_index(forecast) : end_index
        if TimeSeries.timestamp(get_data(forecast))[i] >= timestamp
            fcast = _split_forecast(forecast, get_data(forecast); is_copy=false)
            fcast.start_index = i
            fcast.horizon = end_index - i
            return fcast
        end
    end

    # Do whatever TimeSeries does if the timestamp is after the forecast.
    return _split_forecast(forecast, TimeSeries.from(get_timeseries(forecast), timestamp))
end

"""
    to(forecast::Forecast, timestamp)

Return a forecast truncated after timestamp. Underlying data is not copied.
"""
function to(forecast::Forecast, timestamp)
    # Don't use TimeSeries.from because it makes a copy.
    start_index = get_start_index(forecast)
    end_index = start_index + get_horizon(forecast)
    for i in get_start_index(forecast) : end_index
        tstamp = TimeSeries.timestamp(get_data(forecast))[i]
        if tstamp < timestamp
            continue
        elseif tstamp == timestamp
            end_index = i
        else
            @assert tstamp > timestamp
            end_index = i - 1
        end

        fcast = _split_forecast(forecast, get_data(forecast); is_copy=false)
        fcast.horizon = end_index - start_index + 1
        return fcast
    end

    # Do whatever TimeSeries does if the timestamp is after the forecast.
    return _split_forecast(forecast, TimeSeries.to(get_timeseries(forecast), timestamp))
end

"""
    head(forecast::Forecast)
    head(forecast::Forecast, num)

Return a forecast with only the first num values.
"""
function head(forecast::Forecast)
    return _split_forecast(forecast, TimeSeries.head(get_timeseries(forecast)))
end

function head(forecast::Forecast, num)
    return _split_forecast(forecast, TimeSeries.head(get_timeseries(forecast), num))
end

"""
    tail(forecast::Forecast)
    tail(forecast::Forecast, num)

Return a forecast with only the ending num values.
"""
function tail(forecast::Forecast)
    return _split_forecast(forecast, TimeSeries.tail(get_timeseries(forecast)))
end

function tail(forecast::Forecast, num)
    return _split_forecast(forecast, TimeSeries.tail(get_timeseries(forecast), num))
end
