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
The caller must also remove the actual time series data.
"""
function remove_time_series_metadata!(
    ::Type{T},
    component::InfrastructureSystemsComponent,
    initial_time::Dates.DateTime,
    name::AbstractString,
) where {T <: TimeSeriesMetadata}
    remove_time_series!(T, get_time_series_container(component), initial_time, name)
    @debug "Removed time_series from $component:  $initial_time $name."
end

function clear_time_series!(component::InfrastructureSystemsComponent)
    container = get_time_series_container(component)
    if !isnothing(container)
        clear_time_series!(container)
        @debug "Cleared time_series in $component."
    end
end

function _get_column_index(start_time, count, ts_metadata::ForecastMetadata)
    offset = start_time - get_initial_timestamp(ts_metadata)
    interval = get_interval(ts_metadata)
    index = Int(offset / interval) + 1

    if index + count - 1 > get_count(ts_metadata)
        throw(ArgumentError("The requested start_time $start_time and count $count are invalid"))
    end

    return index
end

_get_column_index(start_time, count, ts_metadata::StaticTimeSeriesMetadata) = 1

function _get_row_index(start_time, len, ts_metadata::StaticTimeSeriesMetadata)
    index =
        Int((start_time - get_initial_time(ts_metadata)) / get_resolution(ts_metadata)) + 1
    if len === nothing
        len = length(ts_metadata) - index + 1
    end
    if index + len - 1 > length(ts_metadata)
        throw(ArgumentError("The requested index=$index len=$len exceed the range $(length(ts_metadata))"))
    end

    return (index, len)
end

function _get_row_index(start_time, len, ts_metadata::ForecastMetadata)
    if len === nothing
        len = get_horizon(ts_metadata)
    end

    return (1, len)
end

function _check_start_time(start_time, ts_metadata::TimeSeriesMetadata)
    if start_time === nothing
        return get_initial_timestamp(ts_metadata)
    end

    time_diff = start_time - get_initial_timestamp(ts_metadata)
    if time_diff < Dates.Second(0)
        throw(ArgumentError("start_time=$start_time is earlier than $(get_initial_time(ts_metadata))"))
    end

    if typeof(ts_metadata) <: ForecastMetadata
        interval = get_interval(ts_metadata)
        if time_diff % interval != Dates.Second(0)
            throw(ArgumentError("start_time=$start_time is not on a multiple of interval=$interval"))
        end
    end

    return start_time
end

"""
Return a time_series for the entire time series range stored for these parameters.
"""
function get_time_series(
    ::Type{T},
    component::InfrastructureSystemsComponent,
    name::AbstractString;
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Nothing, Int} = nothing,
    count::Int = 1,
) where {T <: TimeSeriesData}
    if !has_time_series(component)
        throw(ArgumentError("no forecasts are stored in $component"))
    end

    metadata_type = time_series_data_to_metadata(T)
    ts_metadata = get_time_series(metadata_type, component, name)
    start_time = _check_start_time(start_time, ts_metadata)
    row_index, len = _get_row_index(start_time, len, ts_metadata)
    column_index = _get_column_index(start_time, count, ts_metadata)
    storage = _get_time_series_storage(component)
    return T(
        ts_metadata,
        get_time_series(
            storage,
            get_time_series_uuid(ts_metadata),
            row_index,
            column_index,
            len,
            count,
        ),
    )
end

function get_time_series(
    ::Type{T},
    component::InfrastructureSystemsComponent,
    name::AbstractString,
) where {T <: TimeSeriesMetadata}
    return get_time_series(T, get_time_series_container(component), name)
end

function _make_time_series(
    ::Type{T},
    component::InfrastructureSystemsComponent,
    start_index::Int,
    len::Int,
    initial_time::Dates.DateTime,
    name::AbstractString,
) where {T <: TimeSeriesMetadata}
    container = get_time_series_container(component)
    ts_metadata = get_time_series(T, container, name)
    ta = get_time_series(
        _get_time_series_storage(component),
        get_time_series_uuid(ts_metadata);
        index = start_index,
        len = len,
    )
    return T(ts_metadata, ta)
end

"""
Return a TimeSeries.TimeArray for the given time series parameters.

If the data are scaling factors then the stored scaling_factor_multiplier will be called on
the component and applied to the data.
"""
function get_time_series_array(
    ::Type{T},
    component::InfrastructureSystemsComponent,
    initial_time::Dates.DateTime,
    name::AbstractString,
    horizon::Union{Nothing, Int} = nothing,
) where {T <: TimeSeriesData}
    if horizon === nothing
        time_series = get_time_series(T, component, initial_time, name)
    else
        time_series = get_time_series(T, component, initial_time, name, horizon)
    end

    return get_time_series_array(component, time_series)
end

function get_time_series_array(
    component::InfrastructureSystemsComponent,
    time_series::TimeSeriesData,
)
    ta = get_data(time_series)
    multiplier = get_scaling_factor_multiplier(time_series)
    if multiplier === nothing
        return ta
    end

    return ta .* multiplier(component)
end

function get_time_series_timestamps(
    ::Type{T},
    component::InfrastructureSystemsComponent,
    initial_time::Dates.DateTime,
    name::AbstractString,
    horizon::Union{Nothing, Int} = nothing,
) where {T <: TimeSeriesData}
    return (TimeSeries.timestamp ∘ get_time_series_array)(
        T,
        component,
        initial_time,
        name,
        horizon,
    )
end

function get_time_series_timestamps(
    component::InfrastructureSystemsComponent,
    time_series::TimeSeriesData,
)
    return (TimeSeries.timestamp ∘ get_time_series_array)(component, time_series)
end

"""
Return an Array of values for the requested time series parameters.
"""
function get_time_series_values(
    ::Type{T},
    component::InfrastructureSystemsComponent,
    initial_time::Dates.DateTime,
    name::AbstractString,
    horizon::Union{Nothing, Int} = nothing,
) where {T <: TimeSeriesData}
    return (TimeSeries.values ∘ get_time_series_array)(
        T,
        component,
        initial_time,
        name,
        horizon,
    )
end

function get_time_series_values(
    component::InfrastructureSystemsComponent,
    time_series::TimeSeriesData,
)
    return (TimeSeries.values ∘ get_time_series_array)(component, time_series)
end

function has_time_series(component::InfrastructureSystemsComponent)
    container = get_time_series_container(component)
    return !isnothing(container) && !isempty(container)
end

function get_time_series_initial_times(
    ::Type{T},
    component::InfrastructureSystemsComponent,
) where {T <: TimeSeriesData}
    if !has_time_series(component)
        throw(ArgumentError("$(typeof(component)) does not have time_series"))
    end
    return get_time_series_initial_times(
        time_series_data_to_metadata(T),
        get_time_series_container(component),
    )
end

function get_time_series_initial_times(
    ::Type{T},
    component::InfrastructureSystemsComponent,
    name::AbstractString,
) where {T <: TimeSeriesData}
    if !has_time_series(component)
        throw(ArgumentError("$(typeof(component)) does not have time_series"))
    end
    return get_time_series_initial_times(
        time_series_data_to_metadata(T),
        get_time_series_container(component),
        name,
    )
end

function get_time_series_initial_times!(
    initial_times::Set{Dates.DateTime},
    component::InfrastructureSystemsComponent,
)
    if !has_time_series(component)
        throw(ArgumentError("$(typeof(component)) does not have time_series"))
    end

    get_time_series_initial_times!(initial_times, get_time_series_container(component))
end

function get_time_series_initial_times(component::InfrastructureSystemsComponent)
    if !has_time_series(component)
        throw(ArgumentError("$(typeof(component)) does not have time_series"))
    end

    initial_times = Set{Dates.DateTime}()
    get_time_series_initial_times!(initial_times, component)

    return sort!(collect(initial_times))
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
    initial_time::Dates.DateTime,
) where {T <: TimeSeriesData}
    return get_time_series_names(
        time_series_data_to_metadata(T),
        get_time_series_container(component),
        initial_time,
    )
end

function get_num_time_series(component::InfrastructureSystemsComponent)
    container = get_time_series_container(component)
    if isnothing(container)
        return 0
    end

    return length(container.data)
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
    @debug "cleared all time series data from" component
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
- `initial_time = nothing`: Only return time_series matching this value.
- `name = nothing`: Only return time_series matching this value.
"""
function get_time_series_multiple(
    component::InfrastructureSystemsComponent,
    filter_func = nothing;
    type = nothing,
    initial_time = nothing,
    name = nothing,
)
    container = get_time_series_container(component)
    time_series_keys = sort!(collect(keys(container.data)), by = x -> x.initial_time)
    storage = _get_time_series_storage(component)
    if storage === nothing
        @assert isempty(time_series_keys)
    end

    Channel() do channel
        for key in time_series_keys
            if !isnothing(type) &&
               !(time_series_metadata_to_data(key.time_series_type) <: type)
                continue
            end
            if !isnothing(initial_time) && key.initial_time != initial_time
                continue
            end
            if !isnothing(name) && key.name != name
                continue
            end
            ts_metadata = container.data[key]
            ta = get_time_series(storage, get_time_series_uuid(ts_metadata))
            ts_type = time_series_metadata_to_data(typeof(ts_metadata))
            ts_data = ts_type(ts_metadata, ta)
            if !isnothing(filter_func) && !filter_func(ts_data)
                continue
            end
            put!(channel, ts_data)
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
    time_series_keys = sort!(collect(keys(container.data)), by = x -> x.initial_time)

    Channel() do channel
        for key in time_series_keys
            put!(channel, container.data[key])
        end
    end
end

function clear_time_series_storage!(component::InfrastructureSystemsComponent)
    storage = _get_time_series_storage(component)
    if !isnothing(storage)
        for (uuid, name) in get_time_series_uuids(component)
            remove_time_series!(storage, uuid, get_uuid(component), name)
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

function validate_time_series_consistency(component::InfrastructureSystemsComponent)
    # Initial times for each name must be identical.
    initial_times = Dict{String, Vector{Dates.DateTime}}()
    for key in keys(get_time_series_container(component).data)
        if !haskey(initial_times, key.name)
            initial_times[key.name] = Vector{Dates.DateTime}()
        end
        push!(initial_times[key.name], key.initial_time)
    end

    if isempty(initial_times)
        return true
    end

    base_its = nothing
    for (name, its) in initial_times
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

function _get_time_series_storage(component::InfrastructureSystemsComponent)
    container = get_time_series_container(component)
    if isnothing(container)
        return nothing
    end

    return container.time_series_storage
end
