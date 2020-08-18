function add_forecast!(
    component::T,
    forecast::ForecastInternal;
    skip_if_present = false,
) where {T <: InfrastructureSystemsType}
    component_name = get_name(component)
    container = get_forecasts(component)
    if isnothing(container)
        throw(ArgumentError("type $T does not support storing forecasts"))
    end

    add_forecast!(container, forecast, skip_if_present = skip_if_present)
    @debug "Added $forecast to $(typeof(component)) $(component_name) " *
           "num_forecasts=$(length(get_forecasts(component).data))."
end

"""
Removes the metadata for a forecast.
The caller must also remove the actual time series data.
"""
function remove_forecast_internal!(
    ::Type{T},
    component::InfrastructureSystemsType,
    initial_time::Dates.DateTime,
    label::AbstractString,
) where {T <: ForecastInternal}
    remove_forecast!(T, get_forecasts(component), initial_time, label)
    @debug "Removed forecast from $component:  $initial_time $label."
end

function clear_forecasts!(component::InfrastructureSystemsType)
    container = get_forecasts(component)
    if !isnothing(container)
        clear_forecasts!(container)
        @debug "Cleared forecasts in $component."
    end
end

"""
Return a forecast for the entire time series range stored for these parameters.
"""
function get_forecast(
    ::Type{T},
    component::InfrastructureSystemsType,
    initial_time::Dates.DateTime,
    label::AbstractString,
) where {T <: Forecast}
    forecast_type = forecast_external_to_internal(T)
    forecast = get_forecast(forecast_type, component, initial_time, label)
    storage = _get_time_series_storage(component)
    ts = get_time_series(storage, get_time_series_uuid(forecast))
    return make_public_forecast(forecast, ts)
end

"""
Return a forecast for a subset of the time series range stored for these parameters.
The range may span time series arrays as long as those timestamps are contiguous.
"""
function get_forecast(
    ::Type{T},
    component::InfrastructureSystemsType,
    initial_time::Dates.DateTime,
    label::AbstractString,
    horizon::Int,
) where {T <: Forecast}
    if !has_forecasts(component)
        throw(ArgumentError("no forecasts are stored in $component"))
    end

    first_forecast = iterate(iterate_forecasts(ForecastInternal, component))[1]
    resolution = get_resolution(first_forecast)
    sys_horizon = get_horizon(first_forecast)

    forecast = get_forecast(
        forecast_external_to_internal(T),
        component,
        initial_time,
        resolution,
        sys_horizon,
        label,
        horizon,
    )

    return forecast
end

function get_forecast(
    ::Type{T},
    component::InfrastructureSystemsType,
    initial_time::Dates.DateTime,
    label::AbstractString,
) where {T <: ForecastInternal}
    return get_forecast(T, get_forecasts(component), initial_time, label)
end

function get_forecast(
    ::Type{T},
    component::InfrastructureSystemsType,
    initial_time::Dates.DateTime,
    sys_resolution::Dates.Period,
    sys_horizon::Int,
    label::AbstractString,
    horizon::Int,
) where {T <: ForecastInternal}
    forecast_type = forecast_internal_to_external(T)
    @debug "Requested forecast" get_name(component) forecast_type label initial_time horizon
    forecasts = Vector{forecast_type}()
    end_time = initial_time + sys_resolution * horizon
    initial_times = get_forecast_initial_times(T, get_forecasts(component), label)

    times_remaining = horizon
    found_start = false

    # This code concatenates ranges of contiguous forecasts.
    # Each initial_time represents one time series array that is stored.
    # Each array has a length equal to the system horizon.
    for it in initial_times
        len = 0
        if !found_start
            end_chunk = it + sys_resolution * sys_horizon
            if it <= initial_time && end_chunk > initial_time
                start_index = Int((initial_time - it) / sys_resolution) + 1
                found_start = true
            else
                # Keep looking for the start.
                continue
            end
            if end_chunk >= end_time
                end_index = sys_horizon - Int((end_chunk - end_time) / sys_resolution)
                len = end_index - start_index + 1
            else
                len = sys_horizon - start_index + 1
            end
        else
            start_index = 1
            len = times_remaining > sys_horizon ? sys_horizon : times_remaining
        end

        push!(forecasts, _make_forecast(T, component, start_index, len, it, label))
        times_remaining -= len
        if times_remaining == 0
            break
        end
    end

    if isempty(forecasts)
        throw(ArgumentError("did not find a forecast matching the requested parameters"))
    end

    @assert times_remaining == 0

    # Run the type-specificc constructor that concatenates forecasts.
    return forecast_type(forecasts)
end

function _make_forecast(
    ::Type{T},
    component::InfrastructureSystemsType,
    start_index::Int,
    len::Int,
    initial_time::Dates.DateTime,
    label::AbstractString,
) where {T <: ForecastInternal}
    forecast = get_forecast(T, get_forecasts(component), initial_time, label)
    ts = get_time_series(
        _get_time_series_storage(component),
        get_time_series_uuid(forecast);
        index = start_index,
        len = len,
    )
    return make_public_forecast(forecast, ts)
end

"""
Return a TimeSeries.TimeArray where the forecast data has been multiplied by the forecasted
component field.
"""
function get_forecast_values(
    ::Type{T},
    mod::Module,
    component::InfrastructureSystemsType,
    initial_time::Dates.DateTime,
    label::AbstractString,
) where {T <: Forecast}
    forecast = get_forecast(T, component, initial_time, label)
    return get_forecast_values(mod, component, forecast)
end

function get_forecast_values(
    mod::Module,
    component::InfrastructureSystemsType,
    forecast::Forecast,
)
    scaling_factors = get_data(forecast)
    label = get_label(forecast)
    accessor_func = getfield(mod, Symbol(label))
    data = scaling_factors .* accessor_func(component)
    return data
end

function has_forecasts(component::InfrastructureSystemsType)
    container = get_forecasts(component)
    return !isnothing(container) && !isempty(container)
end

function get_forecast_initial_times(
    ::Type{T},
    component::InfrastructureSystemsType,
) where {T <: Forecast}
    if !has_forecasts(component)
        throw(ArgumentError("$(typeof(component)) does not have forecasts"))
    end
    return get_forecast_initial_times(
        forecast_external_to_internal(T),
        get_forecasts(component),
    )
end

function get_forecast_initial_times(
    ::Type{T},
    component::InfrastructureSystemsType,
    label::AbstractString,
) where {T <: Forecast}
    if !has_forecasts(component)
        throw(ArgumentError("$(typeof(component)) does not have forecasts"))
    end
    return get_forecast_initial_times(
        forecast_external_to_internal(T),
        get_forecasts(component),
        label,
    )
end

function get_forecast_initial_times!(
    initial_times::Set{Dates.DateTime},
    component::InfrastructureSystemsType,
)
    if !has_forecasts(component)
        throw(ArgumentError("$(typeof(component)) does not have forecasts"))
    end

    get_forecast_initial_times!(initial_times, get_forecasts(component))
end

function get_forecast_initial_times(component::InfrastructureSystemsType)
    if !has_forecasts(component)
        throw(ArgumentError("$(typeof(component)) does not have forecasts"))
    end

    initial_times = Set{Dates.DateTime}()
    get_forecast_initial_times!(initial_times, component)

    return sort!(collect(initial_times))
end

"""
Generates all possible initial times for the stored forecasts. This should return the same
result regardless of whether the forecasts have been stored as one contiguous array or
chunks of contiguous arrays, such as one 365-day forecast vs 365 one-day forecasts.

Throws ArgumentError if there are no forecasts stored, interval is not a multiple of the
system's forecast resolution, or if the stored forecasts have overlapping timestamps.

# Arguments
- `component::InfrastructureSystemsType`: Component containing forecasts.
- `interval::Dates.Period`: Amount of time in between each initial time.
- `horizon::Int`: Length of each forecast array.
- `initial_time::Union{Nothing, Dates.DateTime}=nothing`: Start with this time. If nothing,
  use the first initial time.
"""
function generate_initial_times(
    component::InfrastructureSystemsType,
    interval::Dates.Period,
    horizon::Int;
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
)
    # This throws if no forecasts.
    existing_initial_times = get_forecast_initial_times(component)

    first_forecast = iterate(iterate_forecasts(ForecastInternal, component))[1]
    resolution = Dates.Second(get_resolution(first_forecast))
    sys_horizon = get_horizon(first_forecast)

    first_initial_time, total_horizon = check_contiguous_forecasts(
        component,
        existing_initial_times,
        resolution,
        sys_horizon,
    )

    if isnothing(initial_time)
        initial_time = first_initial_time
    end

    interval = Dates.Second(interval)

    if interval % resolution != Dates.Second(0)
        throw(ConflictingInputsError("interval = $interval is not a multiple of resolution = $resolution"))
    end

    last_initial_time =
        first_initial_time + total_horizon * resolution - horizon * resolution
    initial_times = Vector{Dates.DateTime}()
    for it in range(initial_time, step = interval, stop = last_initial_time)
        push!(initial_times, it)
    end

    return initial_times
end

"""
Return true if the forecasts are contiguous.
"""
function are_forecasts_contiguous(component::InfrastructureSystemsType)
    existing_initial_times = get_forecast_initial_times(component)
    first_initial_time = existing_initial_times[1]

    first_forecast = iterate(iterate_forecasts(ForecastInternal, component))[1]
    resolution = Dates.Second(get_resolution(first_forecast))
    horizon = get_horizon(first_forecast)
    total_horizon = horizon * length(existing_initial_times)

    return _are_forecasts_contiguous(existing_initial_times, resolution, horizon)
end

function _are_forecasts_contiguous(initial_times, resolution, horizon)
    if length(initial_times) == 1
        return true
    end

    for i in range(2, stop = length(initial_times))
        if initial_times[i] != initial_times[i - 1] + resolution * horizon
            return false
        end
    end

    return true
end

"""
Throws ArgumentError if the forecasts are not in consecutive order.
"""
function check_contiguous_forecasts(
    component::InfrastructureSystemsType,
    existing_initial_times,
    resolution::Dates.Period,
    horizon::Int,
)
    if !_are_forecasts_contiguous(existing_initial_times, resolution, horizon)
        throw(ArgumentError("generate_initial_times is not allowed with overlapping timestamps"))
    end

    first_initial_time = existing_initial_times[1]
    total_horizon = horizon * length(existing_initial_times)
    return first_initial_time, total_horizon
end

"""
Efficiently add all forecasts in one component to another by copying the underlying
references.

# Arguments
- `src::InfrastructureSystemsType`: Source component
- `dst::InfrastructureSystemsType`: Destination component
- `label_mapping::Dict = nothing`: Optionally map src labels to different dst labels.
  If provided and src has a forecast with a label not present in label_mapping, that
  forecast will not copied. If label_mapping is nothing then all forecasts will be copied
  with src's labels.
"""
function copy_forecasts!(
    src::InfrastructureSystemsType,
    dst::InfrastructureSystemsType,
    label_mapping::Union{Nothing, Dict{String, String}} = nothing,
)
    for forecast in iterate_forecasts(ForecastInternal, src)
        label = get_label(forecast)
        new_label = label
        if !isnothing(label_mapping)
            new_label = get(label_mapping, label, nothing)
            if isnothing(new_label)
                @debug "Skip copying forecast" label
                continue
            end
            @debug "Copy forecast with" new_label
        end
        new_forecast = deepcopy(forecast)
        assign_new_uuid!(new_forecast)
        set_label!(new_forecast, new_label)
        add_forecast!(dst, new_forecast)
        storage = _get_time_series_storage(dst)
        if isnothing(storage)
            throw(ArgumentError("component does not have time series storage"))
        end
        ts_uuid = get_time_series_uuid(forecast)
        add_time_series_reference!(storage, get_uuid(dst), new_label, ts_uuid)
    end
end

function get_forecast_keys(component::InfrastructureSystemsType)
    return keys(get_forecasts(component).data)
end

function get_forecast_labels(
    ::Type{T},
    component::InfrastructureSystemsType,
    initial_time::Dates.DateTime,
) where {T <: Forecast}
    return get_forecast_labels(
        forecast_external_to_internal(T),
        get_forecasts(component),
        initial_time,
    )
end

function get_num_forecasts(component::InfrastructureSystemsType)
    container = get_forecasts(component)
    if isnothing(container)
        return 0
    end

    return length(container.data)
end

function get_time_series(component::InfrastructureSystemsType, forecast::Forecast)
    storage = _get_time_series_storage(component)
    return get_time_series(storage, get_time_series_uuid(forecast))
end

function get_time_series_uuids(component::InfrastructureSystemsType)
    container = get_forecasts(component)

    return [
        (get_time_series_uuid(container.data[key]), key.label)
        for key in get_forecast_keys(component)
    ]
end

"""
This function must be called when a component is removed from a system.
"""
function prepare_for_removal!(component::InfrastructureSystemsType)
    # Forecasts can only be part of a component when that component is part of a system.
    clear_time_series!(component)
    set_time_series_storage!(component, nothing)
    clear_forecasts!(component)
    @debug "cleared all forecast data from" component
end

"""
Returns an iterator of Forecast instances attached to the component.

Note that passing a filter function can be much slower than the other filtering parameters
because it reads time series data from media.

Call `collect` on the result to get an array.

# Arguments
- `component::InfrastructureSystemsType`: component from which to get forecasts
- `filter_func = nothing`: Only return forecasts for which this returns true.
- `type = nothing`: Only return forecasts with this type.
- `initial_time = nothing`: Only return forecasts matching this value.
- `label = nothing`: Only return forecasts matching this value.
"""
function iterate_forecasts(
    component::InfrastructureSystemsType,
    filter_func = nothing;
    type = nothing,
    initial_time = nothing,
    label = nothing,
)
    container = get_forecasts(component)
    forecast_keys = sort!(collect(keys(container.data)), by = x -> x.initial_time)

    Channel() do channel
        for key in forecast_keys
            if !isnothing(type) &&
               !(forecast_internal_to_external(key.forecast_type) <: type)
                continue
            end
            if !isnothing(initial_time) && key.initial_time != initial_time
                continue
            end
            if !isnothing(label) && key.label != label
                continue
            end
            storage = _get_time_series_storage(component)
            forecast_internal = container.data[key]
            time_series = get_time_series(storage, get_time_series_uuid(forecast_internal))
            forecast = make_public_forecast(forecast_internal, time_series)
            if !isnothing(filter_func) && !filter_func(forecast)
                continue
            end
            put!(channel, forecast)
        end
    end
end

"""
Returns an iterator of ForecastInternal instances attached to the component.
"""
function iterate_forecasts(::Type{ForecastInternal}, component::InfrastructureSystemsType)
    container = get_forecasts(component)
    forecast_keys = sort!(collect(keys(container.data)), by = x -> x.initial_time)

    Channel() do channel
        for key in forecast_keys
            put!(channel, container.data[key])
        end
    end
end

function clear_time_series!(component::InfrastructureSystemsType)
    storage = _get_time_series_storage(component)
    if !isnothing(storage)
        for (uuid, label) in get_time_series_uuids(component)
            remove_time_series!(storage, uuid, get_uuid(component), label)
        end
    end
end

function set_time_series_storage!(
    component::InfrastructureSystemsType,
    storage::Union{Nothing, TimeSeriesStorage},
)
    container = get_forecasts(component)
    if !isnothing(container)
        set_time_series_storage!(container, storage)
    end
end

function validate_forecast_consistency(component::InfrastructureSystemsType)
    # Initial times for each label must be identical.
    initial_times = Dict{String, Vector{Dates.DateTime}}()
    for key in keys(get_forecasts(component).data)
        if !haskey(initial_times, key.label)
            initial_times[key.label] = Vector{Dates.DateTime}()
        end
        push!(initial_times[key.label], key.initial_time)
    end

    if isempty(initial_times)
        return true
    end

    base_its = nothing
    for (label, its) in initial_times
        sort!(its)
        if isnothing(base_its)
            base_its = its
        elseif its != base_its
            @error "initial times don't match" base_its, its
            return false
        end
    end

    return true
end

function _get_time_series_storage(component::InfrastructureSystemsType)
    container = get_forecasts(component)
    if isnothing(container)
        return nothing
    end

    return container.time_series_storage
end
