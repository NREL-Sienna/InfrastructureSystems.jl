function add_time_series!(
    component::T,
    time_series::TimeSeriesMetadata;
    skip_if_present = false,
) where {T <: InfrastructureSystemsComponent}
    component_name = get_name(component)
    container = get_time_series_container(component)
    if isnothing(container)
        throw(ArgumentError("type $T does not support storing time series"))
    end

    add_time_series!(container, time_series, skip_if_present = skip_if_present)
    @debug "Added $time_series to $(typeof(component)) $(component_name) " *
           "num_time_series=$(length(get_time_series_container(component).data))."
end

"""
Removes the metadata for a time_series.
If this returns true then the caller must also remove the actual time series data.
"""
function remove_time_series_metadata!(
    component::InfrastructureSystemsComponent,
    ::Type{T},
    name::AbstractString,
) where {T <: TimeSeriesMetadata}
    container = get_time_series_container(component)
    remove_time_series!(container, T, name)
    @debug "Removed time_series from $(get_name(component)):  $name."
    if T <: DeterministicMetadata &&
       has_time_series(container, SingleTimeSeriesMetadata, name)
        return false
    elseif T <: SingleTimeSeriesMetadata &&
           has_time_series(container, DeterministicMetadata, name)
        return false
    end

    return true
end

function clear_time_series!(component::InfrastructureSystemsComponent)
    container = get_time_series_container(component)
    if !isnothing(container)
        clear_time_series!(container)
        @debug "Cleared time_series in $(get_name(component))."
    end
end

function _get_columns(start_time, count, ts_metadata::ForecastMetadata)
    offset = start_time - get_initial_timestamp(ts_metadata)
    interval = time_period_conversion(get_interval(ts_metadata))
    window_count = get_count(ts_metadata)
    if window_count > 1
        index = Int(offset / interval) + 1
    else
        @assert interval == Dates.Millisecond(0)
        index = 1
    end
    if count === nothing
        count = window_count - index + 1
    end

    if index + count - 1 > get_count(ts_metadata)
        throw(ArgumentError("The requested start_time $start_time and count $count are invalid"))
    end
    return UnitRange(index, index + count - 1)
end

_get_columns(start_time, count, ts_metadata::StaticTimeSeriesMetadata) = UnitRange(1, 1)

function _get_rows(start_time, len, ts_metadata::StaticTimeSeriesMetadata)
    index =
        Int(
            (start_time - get_initial_timestamp(ts_metadata)) / get_resolution(ts_metadata),
        ) + 1
    if len === nothing
        len = length(ts_metadata) - index + 1
    end
    if index + len - 1 > length(ts_metadata)
        throw(ArgumentError("The requested index=$index len=$len exceeds the range $(length(ts_metadata))"))
    end

    return UnitRange(index, index + len - 1)
end

function _get_rows(start_time, len, ts_metadata::ForecastMetadata)
    if len === nothing
        len = get_horizon(ts_metadata)
    end

    return UnitRange(1, len)
end

function _check_start_time(start_time, ts_metadata::TimeSeriesMetadata)
    if start_time === nothing
        return get_initial_timestamp(ts_metadata)
    end

    time_diff = start_time - get_initial_timestamp(ts_metadata)
    if time_diff < Dates.Second(0)
        throw(ArgumentError("start_time=$start_time is earlier than $(get_initial_timestamp(ts_metadata))"))
    end

    if typeof(ts_metadata) <: ForecastMetadata
        window_count = get_count(ts_metadata)
        interval = get_interval(ts_metadata)
        if window_count > 1 &&
           Dates.Millisecond(time_diff) % Dates.Millisecond(interval) != Dates.Second(0)
            throw(ArgumentError("start_time=$start_time is not on a multiple of interval=$interval"))
        end
    end

    return start_time
end

"""
Return a time series corresponding to the given parameters.

# Arguments
- `::Type{T}`: Concrete subtype of TimeSeriesData to return
- `component::InfrastructureSystemsComponent`: Component containing the time series
- `name::AbstractString`: name of time series
- `start_time::Union{Nothing, Dates.DateTime} = nothing`: If nothing, use the
  `initial_timestamp` of the time series. If T is a subtype of Forecast then `start_time`
  must be the first timstamp of a window.
- `len::Union{Nothing, Int} = nothing`: Length in the time dimension. If nothing, use the
  entire length.
- `count::Union{Nothing, Int} = nothing`: Only applicable to subtypes of Forecast. Number
  of forecast windows starting at `start_time` to return. Defaults to all available.
"""
function get_time_series(
    ::Type{T},
    component::InfrastructureSystemsComponent,
    name::AbstractString;
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Nothing, Int} = nothing,
    count::Union{Nothing, Int} = nothing,
) where {T <: TimeSeriesData}
    if !has_time_series(component)
        throw(ArgumentError("no forecasts are stored in $component"))
    end

    metadata_type = time_series_data_to_metadata(T)
    ts_metadata = get_time_series(metadata_type, component, name)
    start_time = _check_start_time(start_time, ts_metadata)
    rows = _get_rows(start_time, len, ts_metadata)
    columns = _get_columns(start_time, count, ts_metadata)
    storage = _get_time_series_storage(component)
    return deserialize_time_series(T, storage, ts_metadata, rows, columns)
end

function get_time_series(
    ::Type{T},
    component::InfrastructureSystemsComponent,
    name::AbstractString,
) where {T <: TimeSeriesMetadata}
    return get_time_series(T, get_time_series_container(component), name)
end

"""
Return a TimeSeries.TimeArray from storage for the given time series parameters.

If the data are scaling factors then the stored scaling_factor_multiplier will be called on
the component and applied to the data unless ignore_scaling_factors is true.
"""
function get_time_series_array(
    ::Type{T},
    component::InfrastructureSystemsComponent,
    name::AbstractString;
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Nothing, Int} = nothing,
    ignore_scaling_factors = false,
) where {T <: TimeSeriesData}
    ts = get_time_series(T, component, name; start_time = start_time, len = len, count = 1)
    if start_time === nothing
        start_time = get_initial_timestamp(ts)
    end

    return get_time_series_array(
        component,
        ts,
        start_time;
        len = len,
        ignore_scaling_factors = ignore_scaling_factors,
    )
end

"""
Return a TimeSeries.TimeArray for one forecast window from a cached Forecast instance.

If the data are scaling factors then the stored scaling_factor_multiplier will be called on
the component and applied to the data unless ignore_scaling_factors is true.

See also [`ForecastCache`](@ref).
"""
function get_time_series_array(
    component::InfrastructureSystemsComponent,
    forecast::Forecast,
    start_time::Dates.DateTime;
    len = nothing,
    ignore_scaling_factors = false,
)
    return _make_time_array(component, forecast, start_time, len, ignore_scaling_factors)
end

"""
Return a TimeSeries.TimeArray from a cached StaticTimeSeries instance.

If the data are scaling factors then the stored scaling_factor_multiplier will be called on
the component and applied to the data unless ignore_scaling_factors is true.

See also [`StaticTimeSeriesCache`](@ref).
"""
function get_time_series_array(
    component::InfrastructureSystemsComponent,
    time_series::StaticTimeSeries,
    start_time::Union{Nothing, Dates.DateTime} = nothing;
    len::Union{Nothing, Int} = nothing,
    ignore_scaling_factors = false,
)
    if start_time === nothing
        start_time = get_initial_timestamp(time_series)
    end

    if len === nothing
        len = length(time_series)
    end

    return _make_time_array(component, time_series, start_time, len, ignore_scaling_factors)
end

"""
Return a vector of timestamps from storage for the given time series parameters.
"""
function get_time_series_timestamps(
    ::Type{T},
    component::InfrastructureSystemsComponent,
    name::AbstractString;
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Nothing, Int} = nothing,
) where {T <: TimeSeriesData}
    return TimeSeries.timestamp(get_time_series_array(
        T,
        component,
        name;
        start_time = start_time,
        len = len,
    ))
end

"""
Return a vector of timestamps from a cached Forecast instance.
"""
function get_time_series_timestamps(
    component::InfrastructureSystemsComponent,
    forecast::Forecast,
    start_time::Union{Nothing, Dates.DateTime} = nothing;
    len::Union{Nothing, Int} = nothing,
)
    return TimeSeries.timestamp(get_time_series_array(
        component,
        forecast,
        start_time;
        len = len,
    ))
end

"""
Return a vector of timestamps from a cached StaticTimeSeries instance.
"""
function get_time_series_timestamps(
    component::InfrastructureSystemsComponent,
    time_series::StaticTimeSeries,
    start_time::Union{Nothing, Dates.DateTime} = nothing;
    len::Union{Nothing, Int} = nothing,
)
    return TimeSeries.timestamp(get_time_series_array(
        component,
        time_series,
        start_time;
        len = len,
    ))
end

"""
Return an Array of values from storage for the requested time series parameters.

If the data size is small and this will be called many times, consider using the version
that accepts a cached TimeSeriesData instance.
"""
function get_time_series_values(
    ::Type{T},
    component::InfrastructureSystemsComponent,
    name::AbstractString;
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Nothing, Int} = nothing,
    ignore_scaling_factors = false,
) where {T <: TimeSeriesData}
    return TimeSeries.values(get_time_series_array(
        T,
        component,
        name;
        start_time = start_time,
        len = len,
        ignore_scaling_factors = ignore_scaling_factors,
    ))
end

"""
Return an Array of values for one forecast window from a cached Forecast instance.
"""
function get_time_series_values(
    component::InfrastructureSystemsComponent,
    forecast::Forecast,
    start_time::Dates.DateTime;
    len::Union{Nothing, Int} = nothing,
    ignore_scaling_factors = false,
)
    return TimeSeries.values(get_time_series_array(
        component,
        forecast,
        start_time;
        len = len,
        ignore_scaling_factors = ignore_scaling_factors,
    ))
end

"""
Return an Array of values from a cached StaticTimeSeries instance for the requested time
series parameters.
"""
function get_time_series_values(
    component::InfrastructureSystemsComponent,
    time_series::StaticTimeSeries,
    start_time::Union{Nothing, Dates.DateTime} = nothing;
    len::Union{Nothing, Int} = nothing,
    ignore_scaling_factors = false,
)
    return TimeSeries.values(get_time_series_array(
        component,
        time_series,
        start_time;
        len = len,
        ignore_scaling_factors = ignore_scaling_factors,
    ))
end

function _make_time_array(component, time_series, start_time, len, ignore_scaling_factors)
    ta = make_time_array(time_series, start_time; len = len)
    if ignore_scaling_factors
        return ta
    end

    multiplier = get_scaling_factor_multiplier(time_series)
    if multiplier === nothing
        return ta
    end

    return ta .* multiplier(component)
end

function has_time_series(component::InfrastructureSystemsComponent)
    container = get_time_series_container(component)
    return !isnothing(container) && !isempty(container)
end

"""
Efficiently add all time_series in one component to another by copying the underlying
references.

# Arguments
- `dst::InfrastructureSystemsComponent`: Destination component
- `src::InfrastructureSystemsComponent`: Source component
- `name_mapping::Dict = nothing`: Optionally map src names to different dst names.
  If provided and src has a time_series with a name not present in name_mapping, that
  time_series will not copied. If name_mapping is nothing then all time_series will be
  copied with src's names.
- `scaling_factor_multiplier_mapping::Dict = nothing`: Optionally map src multipliers to
  different dst multipliers.  If provided and src has a time_series with a multiplier not
  present in scaling_factor_multiplier_mapping, that time_series will not copied. If
  scaling_factor_multiplier_mapping is nothing then all time_series will be copied with
  src's multipliers.
"""
function copy_time_series!(
    dst::InfrastructureSystemsComponent,
    src::InfrastructureSystemsComponent;
    name_mapping::Union{Nothing, Dict{String, String}} = nothing,
    scaling_factor_multiplier_mapping::Union{Nothing, Dict{String, String}} = nothing,
)
    for ts_metadata in get_time_series_multiple(TimeSeriesMetadata, src)
        name = get_name(ts_metadata)
        new_name = name
        if !isnothing(name_mapping)
            new_name = get(name_mapping, name, nothing)
            if isnothing(new_name)
                @debug "Skip copying ts_metadata" name
                continue
            end
            @debug "Copy ts_metadata with" new_name
        end
        multiplier = get_scaling_factor_multiplier(ts_metadata)
        new_multiplier = multiplier
        if !isnothing(scaling_factor_multiplier_mapping)
            new_multiplier = get(scaling_factor_multiplier_mapping, multiplier, nothing)
            if isnothing(new_multiplier)
                @debug "Skip copying ts_metadata" multiplier
                continue
            end
            @debug "Copy ts_metadata with" new_multiplier
        end
        new_time_series = deepcopy(ts_metadata)
        assign_new_uuid!(new_time_series)
        set_name!(new_time_series, new_name)
        set_scaling_factor_multiplier!(new_time_series, new_multiplier)
        add_time_series!(dst, new_time_series)
        storage = _get_time_series_storage(dst)
        if isnothing(storage)
            throw(ArgumentError("component does not have time series storage"))
        end
        ts_uuid = get_time_series_uuid(ts_metadata)
        add_time_series_reference!(storage, get_uuid(dst), new_name, ts_uuid)
    end
end

function get_time_series_keys(component::InfrastructureSystemsComponent)
    return keys(get_time_series_container(component).data)
end

function get_time_series_names(
    ::Type{T},
    component::InfrastructureSystemsComponent,
) where {T <: TimeSeriesData}
    return get_time_series_names(
        time_series_data_to_metadata(T),
        get_time_series_container(component),
    )
end

function get_num_time_series(component::InfrastructureSystemsComponent)
    container = get_time_series_container(component)
    if isnothing(container)
        return (0, 0)
    end

    static_ts_count = 0
    forecast_count = 0
    for key in keys(container.data)
        if key.time_series_type <: StaticTimeSeriesMetadata
            static_ts_count += 1
        elseif key.time_series_type <: ForecastMetadata
            forecast_count += 1
        else
            error("panic")
        end
    end

    return (static_ts_count, forecast_count)
end

function get_time_series(
    component::InfrastructureSystemsComponent,
    time_series::TimeSeriesData,
)
    storage = _get_time_series_storage(component)
    return get_time_series(storage, get_time_series_uuid(time_series))
end

function get_time_series_uuids(component::InfrastructureSystemsComponent)
    container = get_time_series_container(component)

    return [
        (get_time_series_uuid(container.data[key]), key.name)
        for key in get_time_series_keys(component)
    ]
end

"""
This function must be called when a component is removed from a system.
"""
function prepare_for_removal!(component::InfrastructureSystemsComponent)
    # TimeSeriesContainer can only be part of a component when that component is part of a
    # system.
    clear_time_series_storage!(component)
    set_time_series_storage!(component, nothing)
    clear_time_series!(component)
    @debug "cleared all time series data from" get_name(component)
end

"""
Returns an iterator of TimeSeriesData instances attached to the component.

Note that passing a filter function can be much slower than the other filtering parameters
because it reads time series data from media.

Call `collect` on the result to get an array.

# Arguments
- `component::InfrastructureSystemsComponent`: component from which to get time_series
- `filter_func = nothing`: Only return time_series for which this returns true.
- `type = nothing`: Only return time_series with this type.
- `name = nothing`: Only return time_series matching this value.
"""
function get_time_series_multiple(
    component::InfrastructureSystemsComponent,
    filter_func = nothing;
    type = nothing,
    start_time = nothing,
    name = nothing,
)
    container = get_time_series_container(component)
    storage = _get_time_series_storage(component)

    Channel() do channel
        for key in keys(container.data)
            if !isnothing(type)
                if type == DeterministicSingleTimeSeries
                    # time_series_metadata_to_data will return Deterministic here, so we
                    # must change the type to match.
                    type = Deterministic
                end
                !(time_series_metadata_to_data(key.time_series_type) <: type) && continue
            end
            if !isnothing(name) && key.name != name
                continue
            end
            ts_metadata = container.data[key]
            ts_type = time_series_metadata_to_data(typeof(ts_metadata))
            ts = deserialize_time_series(
                ts_type,
                storage,
                ts_metadata,
                UnitRange(1, length(ts_metadata)),
                UnitRange(1, get_count(ts_metadata)),
            )
            if !isnothing(filter_func) && !filter_func(ts)
                continue
            end
            put!(channel, ts)
        end
    end
end

"""
Returns an iterator of TimeSeriesMetadata instances attached to the component.
"""
function get_time_series_multiple(
    ::Type{TimeSeriesMetadata},
    component::InfrastructureSystemsComponent,
)
    container = get_time_series_container(component)
    Channel() do channel
        for key in keys(container.data)
            put!(channel, container.data[key])
        end
    end
end

"""
Transform all instances of SingleTimeSeries to DeterministicSingleTimeSeries.
"""
function transform_single_time_series!(
    component::InfrastructureSystemsComponent,
    ::Type{T},
    sys_params::TimeSeriesParameters,
) where {T <: DeterministicSingleTimeSeries}
    container = get_time_series_container(component)
    for (key, ts_metadata) in container.data
        if ts_metadata isa SingleTimeSeriesMetadata
            resolution = get_resolution(ts_metadata)
            params = _get_single_time_series_transformed_parameters(
                ts_metadata,
                T,
                sys_params.forecast_params.horizon,
                sys_params.forecast_params.interval,
            )
            check_add_time_series!(sys_params, params)
            new_metadata = DeterministicMetadata(
                name = get_name(ts_metadata),
                resolution = params.resolution,
                initial_timestamp = params.forecast_params.initial_timestamp,
                interval = params.forecast_params.interval,
                count = params.forecast_params.count,
                time_series_uuid = get_time_series_uuid(ts_metadata),
                horizon = params.forecast_params.horizon,
                scaling_factor_multiplier = get_scaling_factor_multiplier(ts_metadata),
                internal = get_internal(ts_metadata),
            )
            add_time_series!(container, new_metadata)
            @debug "Added $new_metadata from $ts_metadata."
        end
    end
end

function get_single_time_series_transformed_parameters(
    component::InfrastructureSystemsComponent,
    ::Type{T},
    horizon::Int,
    interval::Dates.Period,
) where {T <: Forecast}
    container = get_time_series_container(component)
    for (key, ts_metadata) in container.data
        if ts_metadata isa SingleTimeSeriesMetadata
            return _get_single_time_series_transformed_parameters(
                ts_metadata,
                T,
                horizon,
                interval,
            )
        end
    end

    throw(ArgumentError("component $(get_name(component)) does not have SingleTimeSeries"))
end

function _get_single_time_series_transformed_parameters(
    ts_metadata::SingleTimeSeriesMetadata,
    ::Type{T},
    horizon::Int,
    interval::Dates.Period,
) where {T <: Forecast}
    resolution = get_resolution(ts_metadata)
    len = length(ts_metadata)
    if len < horizon
        throw(ConflictingInputsError("existing length=$len is shorter than horizon=$horizon"))
    end

    max_interval = horizon * resolution
    if len == horizon && interval == max_interval
        interval = Dates.Second(0)
        @warn "There is only one forecast window. Setting interval = $interval"
    elseif interval > max_interval
        throw(ConflictingInputsError("interval = $interval is bigger than the max of $max_interval"))
    end

    initial_timestamp = get_initial_timestamp(ts_metadata)
    return TimeSeriesParameters(initial_timestamp, resolution, len, horizon, interval)
end

function clear_time_series_storage!(component::InfrastructureSystemsComponent)
    storage = _get_time_series_storage(component)
    if !isnothing(storage)
        # In the case of Deterministic and DeterministicSingleTimeSeries the UUIDs
        # can be shared.
        uuids = Set{Base.UUID}()
        for (uuid, name) in get_time_series_uuids(component)
            if !(uuid in uuids)
                remove_time_series!(storage, uuid, get_uuid(component), name)
                push!(uuids, uuid)
            end
        end
    end
end

function set_time_series_storage!(
    component::InfrastructureSystemsComponent,
    storage::Union{Nothing, TimeSeriesStorage},
)
    container = get_time_series_container(component)
    if !isnothing(container)
        set_time_series_storage!(container, storage)
    end
end

function _get_time_series_storage(component::InfrastructureSystemsComponent)
    container = get_time_series_container(component)
    if isnothing(container)
        return nothing
    end

    return container.time_series_storage
end

function get_time_series_by_key(
    key::TimeSeriesKey,
    component::InfrastructureSystemsComponent;
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Nothing, Int} = nothing,
    count::Union{Nothing, Int} = nothing,
)
    return get_time_series(
        time_series_metadata_to_data(key.time_series_type),
        component,
        key.name,
        start_time = start_time,
        len = len,
        count = count,
    )
end
