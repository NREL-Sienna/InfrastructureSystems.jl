const SUPPORTED_TIME_SERIES_TYPES =
    Union{InfrastructureSystemsComponent, InfrastructureSystemsSupplementalAttribute}

function add_time_series!(
    component::T,
    time_series::TimeSeriesMetadata;
    skip_if_present=false,
) where {T <: SUPPORTED_TIME_SERIES_TYPES}
    component_id = get_uuid(component)
    container = get_time_series_container(component)
    if isnothing(container)
        throw(ArgumentError("type $T does not support storing time series"))
    end

    add_time_series!(container, time_series, skip_if_present=skip_if_present)
    @debug "Added $time_series to $(typeof(component)) $(component_id) " *
           "num_time_series=$(length(get_time_series_container(component).data))." _group =
        LOG_GROUP_TIME_SERIES
end

"""
Removes the metadata for a time_series.
If this returns true then the caller must also remove the actual time series data.
"""
function remove_time_series_metadata!(
    component::SUPPORTED_TIME_SERIES_TYPES,
    ::Type{T},
    name::AbstractString,
) where {T <: TimeSeriesMetadata}
    container = get_time_series_container(component)
    remove_time_series!(container, T, name)
    @debug "Removed time_series from $(get_name(component)):  $name." _group =
        LOG_GROUP_TIME_SERIES
    if T <: DeterministicMetadata &&
       has_time_series_internal(container, SingleTimeSeriesMetadata, name)
        return false
    elseif T <: SingleTimeSeriesMetadata &&
           has_time_series_internal(container, DeterministicMetadata, name)
        return false
    end

    return true
end

function clear_time_series!(component::SUPPORTED_TIME_SERIES_TYPES)
    container = get_time_series_container(component)
    if !isnothing(container)
        clear_time_series!(container)
        @debug "Cleared time_series in $(get_name(component))." _group =
            LOG_GROUP_TIME_SERIES
    end
    return
end

function _get_columns(start_time, count, ts_metadata::ForecastMetadata)
    offset = start_time - get_initial_timestamp(ts_metadata)
    interval = time_period_conversion(get_interval(ts_metadata))
    window_count = get_count(ts_metadata)
    if window_count > 1
        index = Int(offset / interval) + 1
    else
        index = 1
    end
    if count === nothing
        count = window_count - index + 1
    end

    if index + count - 1 > get_count(ts_metadata)
        throw(
            ArgumentError(
                "The requested start_time $start_time and count $count are invalid",
            ),
        )
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
        throw(
            ArgumentError(
                "The requested index=$index len=$len exceeds the range $(length(ts_metadata))",
            ),
        )
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
        throw(
            ArgumentError(
                "start_time=$start_time is earlier than $(get_initial_timestamp(ts_metadata))",
            ),
        )
    end

    if typeof(ts_metadata) <: ForecastMetadata
        window_count = get_count(ts_metadata)
        interval = get_interval(ts_metadata)
        if window_count > 1 &&
           Dates.Millisecond(time_diff) % Dates.Millisecond(interval) != Dates.Second(0)
            throw(
                ArgumentError(
                    "start_time=$start_time is not on a multiple of interval=$interval",
                ),
            )
        end
    end

    return start_time
end

"""
Return a time series corresponding to the given parameters.

# Arguments

  - `::Type{T}`: Concrete subtype of TimeSeriesData to return
  - `component::SUPPORTED_TIME_SERIES_TYPES`: Component containing the time series
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
    component::SUPPORTED_TIME_SERIES_TYPES,
    name::AbstractString;
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Nothing, Int}=nothing,
    count::Union{Nothing, Int}=nothing,
) where {T <: TimeSeriesData}
    if !has_time_series(component)
        throw(ArgumentError("no forecasts are stored in $component"))
    end

    metadata_type = time_series_data_to_metadata(T)
    ts_metadata = get_time_series_metadata(metadata_type, component, name)
    start_time = _check_start_time(start_time, ts_metadata)
    rows = _get_rows(start_time, len, ts_metadata)
    columns = _get_columns(start_time, count, ts_metadata)
    storage = _get_time_series_storage(component)
    return deserialize_time_series(T, storage, ts_metadata, rows, columns)
end

function get_time_series_uuid(
    ::Type{T},
    component::SUPPORTED_TIME_SERIES_TYPES,
    name::AbstractString,
) where {T <: TimeSeriesData}
    metadata_type = time_series_data_to_metadata(T)
    metadata = get_time_series_metadata(metadata_type, component, name)
    return get_time_series_uuid(metadata)
end

function get_time_series_metadata(
    ::Type{T},
    component::SUPPORTED_TIME_SERIES_TYPES,
    name::AbstractString,
) where {T <: TimeSeriesMetadata}
    return get_time_series_metadata(T, get_time_series_container(component), name)
end

"""
Return a TimeSeries.TimeArray from storage for the given time series parameters.

If the data are scaling factors then the stored scaling_factor_multiplier will be called on
the component and applied to the data unless ignore_scaling_factors is true.
"""
function get_time_series_array(
    ::Type{T},
    component::SUPPORTED_TIME_SERIES_TYPES,
    name::AbstractString;
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Nothing, Int}=nothing,
    ignore_scaling_factors=false,
) where {T <: TimeSeriesData}
    ts = get_time_series(T, component, name; start_time=start_time, len=len, count=1)
    if start_time === nothing
        start_time = get_initial_timestamp(ts)
    end

    return get_time_series_array(
        component,
        ts,
        start_time;
        len=len,
        ignore_scaling_factors=ignore_scaling_factors,
    )
end

"""
Return a TimeSeries.TimeArray for one forecast window from a cached Forecast instance.

If the data are scaling factors then the stored scaling_factor_multiplier will be called on
the component and applied to the data unless ignore_scaling_factors is true.

See also [`ForecastCache`](@ref).
"""
function get_time_series_array(
    component::SUPPORTED_TIME_SERIES_TYPES,
    forecast::Forecast,
    start_time::Dates.DateTime;
    len=nothing,
    ignore_scaling_factors=false,
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
    component::SUPPORTED_TIME_SERIES_TYPES,
    time_series::StaticTimeSeries,
    start_time::Union{Nothing, Dates.DateTime}=nothing;
    len::Union{Nothing, Int}=nothing,
    ignore_scaling_factors=false,
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
    component::SUPPORTED_TIME_SERIES_TYPES,
    name::AbstractString;
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Nothing, Int}=nothing,
) where {T <: TimeSeriesData}
    return TimeSeries.timestamp(
        get_time_series_array(T, component, name; start_time=start_time, len=len),
    )
end

"""
Return a vector of timestamps from a cached Forecast instance.
"""
function get_time_series_timestamps(
    component::SUPPORTED_TIME_SERIES_TYPES,
    forecast::Forecast,
    start_time::Union{Nothing, Dates.DateTime}=nothing;
    len::Union{Nothing, Int}=nothing,
)
    return TimeSeries.timestamp(
        get_time_series_array(component, forecast, start_time; len=len),
    )
end

"""
Return a vector of timestamps from a cached StaticTimeSeries instance.
"""
function get_time_series_timestamps(
    component::SUPPORTED_TIME_SERIES_TYPES,
    time_series::StaticTimeSeries,
    start_time::Union{Nothing, Dates.DateTime}=nothing;
    len::Union{Nothing, Int}=nothing,
)
    return TimeSeries.timestamp(
        get_time_series_array(component, time_series, start_time; len=len),
    )
end

"""
Return an Array of values from storage for the requested time series parameters.

If the data size is small and this will be called many times, consider using the version
that accepts a cached TimeSeriesData instance.
"""
function get_time_series_values(
    ::Type{T},
    component::SUPPORTED_TIME_SERIES_TYPES,
    name::AbstractString;
    start_time::Union{Nothing, Dates.DateTime}=nothing,
    len::Union{Nothing, Int}=nothing,
    ignore_scaling_factors=false,
) where {T <: TimeSeriesData}
    return TimeSeries.values(
        get_time_series_array(
            T,
            component,
            name;
            start_time=start_time,
            len=len,
            ignore_scaling_factors=ignore_scaling_factors,
        ),
    )
end

"""
Return an Array of values for one forecast window from a cached Forecast instance.
"""
function get_time_series_values(
    component::SUPPORTED_TIME_SERIES_TYPES,
    forecast::Forecast,
    start_time::Dates.DateTime;
    len::Union{Nothing, Int}=nothing,
    ignore_scaling_factors=false,
)
    return TimeSeries.values(
        get_time_series_array(
            component,
            forecast,
            start_time;
            len=len,
            ignore_scaling_factors=ignore_scaling_factors,
        ),
    )
end

"""
Return an Array of values from a cached StaticTimeSeries instance for the requested time
series parameters.
"""
function get_time_series_values(
    component::SUPPORTED_TIME_SERIES_TYPES,
    time_series::StaticTimeSeries,
    start_time::Union{Nothing, Dates.DateTime}=nothing;
    len::Union{Nothing, Int}=nothing,
    ignore_scaling_factors=false,
)
    return TimeSeries.values(
        get_time_series_array(
            component,
            time_series,
            start_time;
            len=len,
            ignore_scaling_factors=ignore_scaling_factors,
        ),
    )
end

function _make_time_array(component, time_series, start_time, len, ignore_scaling_factors)
    ta = make_time_array(time_series, start_time; len=len)
    if ignore_scaling_factors
        return ta
    end

    multiplier = get_scaling_factor_multiplier(time_series)
    if multiplier === nothing
        return ta
    end

    return ta .* multiplier(component)
end

"""
Return true if the component has time series data.
"""
function has_time_series(component::SUPPORTED_TIME_SERIES_TYPES)
    container = get_time_series_container(component)
    return !isnothing(container) && !isempty(container)
end

"""
Return true if the component has time series data of type T.
"""
function has_time_series(
    component::SUPPORTED_TIME_SERIES_TYPES,
    ::Type{T},
) where {T <: TimeSeriesData}
    container = get_time_series_container(component)
    if container === nothing
        return false
    end

    for key in keys(container.data)
        if isabstracttype(T)
            if is_time_series_sub_type(key.time_series_type, T)
                return true
            end
        elseif time_series_data_to_metadata(T) <: key.time_series_type
            return true
        end
    end

    return false
end

function has_time_series(
    component::SUPPORTED_TIME_SERIES_TYPES,
    type::Type{<:TimeSeriesMetadata},
    name::AbstractString,
)
    container = get_time_series_container(component)
    container === nothing && return false
    return has_time_series_internal(container, type, name)
end

"""
Efficiently add all time_series in one component to another by copying the underlying
references.

# Arguments

  - `dst::SUPPORTED_TIME_SERIES_TYPES`: Destination component
  - `src::SUPPORTED_TIME_SERIES_TYPES`: Source component
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
    dst::SUPPORTED_TIME_SERIES_TYPES,
    src::SUPPORTED_TIME_SERIES_TYPES;
    name_mapping::Union{Nothing, Dict{Tuple{String, String}, String}}=nothing,
    scaling_factor_multiplier_mapping::Union{Nothing, Dict{String, String}}=nothing,
)
    storage = _get_time_series_storage(dst)
    if isnothing(storage)
        throw(
            ArgumentError(
                "Component does not have time series storage. " *
                "It may not be attached to the system.",
            ),
        )
    end

    # There may be time series that share time series arrays as a result of
    # transform_single_time_series! being called.
    # Don't add these references to the storage more than once.
    refs = Set{Tuple{String, Base.UUID}}()

    for ts_metadata in get_time_series_multiple(TimeSeriesMetadata, src)
        name = get_name(ts_metadata)
        new_name = name
        if !isnothing(name_mapping)
            new_name = get(name_mapping, (get_name(src), name), nothing)
            if isnothing(new_name)
                @debug "Skip copying ts_metadata" _group = LOG_GROUP_TIME_SERIES name
                continue
            end
            @debug "Copy ts_metadata with" _group = LOG_GROUP_TIME_SERIES new_name
        end
        multiplier = get_scaling_factor_multiplier(ts_metadata)
        new_multiplier = multiplier
        if !isnothing(scaling_factor_multiplier_mapping)
            new_multiplier = get(scaling_factor_multiplier_mapping, multiplier, nothing)
            if isnothing(new_multiplier)
                @debug "Skip copying ts_metadata" _group = LOG_GROUP_TIME_SERIES multiplier
                continue
            end
            @debug "Copy ts_metadata with" _group = LOG_GROUP_TIME_SERIES new_multiplier
        end
        new_time_series = deepcopy(ts_metadata)
        assign_new_uuid!(new_time_series)
        set_name!(new_time_series, new_name)
        set_scaling_factor_multiplier!(new_time_series, new_multiplier)
        add_time_series!(dst, new_time_series)
        ts_uuid = get_time_series_uuid(new_time_series)
        ref = (new_name, ts_uuid)
        if !in(ref, refs)
            add_time_series_reference!(storage, get_uuid(dst), new_name, ts_uuid)
            push!(refs, ref)
        end
    end
end

function get_time_series_keys(component::SUPPORTED_TIME_SERIES_TYPES)
    return keys(get_time_series_container(component).data)
end

function list_time_series_metadata(component::SUPPORTED_TIME_SERIES_TYPES)
    return collect(values(get_time_series_container(component).data))
end

function get_time_series_names(
    ::Type{T},
    component::SUPPORTED_TIME_SERIES_TYPES,
) where {T <: TimeSeriesData}
    return get_time_series_names(
        time_series_data_to_metadata(T),
        get_time_series_container(component),
    )
end

function get_num_time_series(component::SUPPORTED_TIME_SERIES_TYPES)
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

function get_num_time_series_by_type(component::SUPPORTED_TIME_SERIES_TYPES)
    counts = Dict{String, Int}()
    container = get_time_series_container(component)
    if isnothing(container)
        return counts
    end

    for metadata in values(container.data)
        type = string(nameof(time_series_metadata_to_data(metadata)))
        if haskey(counts, type)
            counts[type] += 1
        else
            counts[type] = 1
        end
    end

    return counts
end

function get_time_series(
    component::SUPPORTED_TIME_SERIES_TYPES,
    time_series::TimeSeriesData,
)
    storage = _get_time_series_storage(component)
    return get_time_series(storage, get_time_series_uuid(time_series))
end

function get_time_series_uuids(component::SUPPORTED_TIME_SERIES_TYPES)
    container = get_time_series_container(component)

    return [
        (get_time_series_uuid(container.data[key]), key.name) for
        key in get_time_series_keys(component)
    ]
end

function attach_time_series_and_serialize!(
    data::SystemData,
    component::SUPPORTED_TIME_SERIES_TYPES,
    ts_metadata::T,
    ts::TimeSeriesData;
    skip_if_present=false,
) where {T <: TimeSeriesMetadata}
    check_add_time_series(data.time_series_params, ts)
    check_read_only(data.time_series_storage)
    if has_time_series(component, T, get_name(ts))
        skip_if_present && return
        throw(ArgumentError("time_series $(typeof(ts)) $(get_name(ts)) is already stored"))
    end

    serialize_time_series!(
        data.time_series_storage,
        get_uuid(component),
        get_name(ts_metadata),
        ts,
    )
    add_time_series!(component, ts_metadata, skip_if_present=skip_if_present)
    # Order is important. Set this last in case exceptions are thrown at previous steps.
    set_parameters!(data.time_series_params, ts)
    return
end
