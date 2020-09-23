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
    label::AbstractString,
) where {T <: TimeSeriesMetadata}
    remove_time_series!(T, get_time_series_container(component), initial_time, label)
    @debug "Removed time_series from $component:  $initial_time $label."
end

function clear_time_series!(component::InfrastructureSystemsComponent)
    container = get_time_series_container(component)
    if !isnothing(container)
        clear_time_series!(container)
        @debug "Cleared time_series in $component."
    end
end

"""
Return a time_series for the entire time series range stored for these parameters.
"""
function get_time_series(
    ::Type{T},
    component::InfrastructureSystemsComponent,
    initial_time::Dates.DateTime,
    label::AbstractString,
) where {T <: AbstractTimeSeriesData}
    time_series_type = time_series_data_to_metadata(T)
    time_series = get_time_series(time_series_type, component, initial_time, label)
    storage = _get_time_series_storage(component)
    ts = get_time_series(storage, get_time_series_uuid(time_series))
    return make_time_series_data(time_series, ts)
end

function _get_forecast_column_no(
    initial_time::Dates.DateTime,
    ts_metadata::TimeSeriesMetadata,
)
    range = initial_time - get_initial_time_stamp(ts_metadata)
    interval = get_interval(ts_metadata)
    return Int(range / interval)
end

function get_time_series(
    ::Type{T},
    component::InfrastructureSystemsComponent,
    initial_time::Dates.DateTime,
    label::AbstractString;
    count::Int = 1,
) where {T <: Forecast}
    time_series_type = time_series_data_to_metadata(T)
    time_series_metadata = get_time_series(time_series_type, component, label)
    storage = _get_time_series_storage(component)
    index = _get_forecast_column_no(initial_time, time_series_metadata)
    ts = get_time_series(storage, get_time_series_uuid(time_series_metadata); index = index)
    return make_time_series_data(time_series_metadata, ts)
end

"""
Return a time_series for a subset of the time series range stored for these parameters.
The range may span time series arrays as long as those timestamps are contiguous.
"""
function get_time_series(
    ::Type{T},
    component::InfrastructureSystemsComponent,
    initial_time::Dates.DateTime,
    label::AbstractString,
    horizon::Int,
) where {T <: AbstractTimeSeriesData}
    if !has_time_series(component)
        throw(ArgumentError("no forecasts are stored in $component"))
    end

    first_time_series = iterate(get_time_series_multiple(TimeSeriesMetadata, component))[1]
    resolution = get_resolution(first_time_series)
    sys_horizon = get_horizon(first_time_series)

    time_series = get_time_series(
        time_series_data_to_metadata(T),
        component,
        initial_time,
        resolution,
        sys_horizon,
        label,
        horizon,
    )

    return time_series
end

function get_time_series(
    ::Type{T},
    component::InfrastructureSystemsComponent,
    initial_time::Dates.DateTime,
    label::AbstractString,
    horizon::Int,
) where {T <: Forecast}
    if !has_time_series(component)
        throw(ArgumentError("no forecasts are stored in $component"))
    end

    first_time_series = iterate(get_time_series_multiple(TimeSeriesMetadata, component))[1]
    resolution = get_resolution(first_time_series)
    sys_horizon = get_horizon(first_time_series)

    time_series = get_time_series(
        time_series_data_to_metadata(T),
        component,
        initial_time,
        resolution,
        sys_horizon,
        label,
        horizon,
    )

    return time_series
end

function get_time_series(
    ::Type{T},
    component::InfrastructureSystemsComponent,
    label::AbstractString,
) where {T <: TimeSeriesMetadata}
    return get_time_series(T, get_time_series_container(component), label)
end

function get_time_series(
    ::Type{T},
    component::InfrastructureSystemsComponent,
    initial_time::Dates.DateTime,
    sys_resolution::Dates.Period,
    sys_horizon::Int,
    label::AbstractString,
    horizon::Int,
) where {T <: TimeSeriesMetadata}
    time_series_type = time_series_metadata_to_data(T)
    @debug "Requested time_series" get_name(component) time_series_type label initial_time horizon
    time_series = Vector{time_series_type}()
    end_time = initial_time + sys_resolution * horizon
    initial_times =
        get_time_series_initial_times(T, get_time_series_container(component), label)

    times_remaining = horizon
    found_start = false

    # This code concatenates ranges of contiguous time_series.
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

        push!(time_series, _make_time_series(T, component, start_index, len, it, label))
        times_remaining -= len
        if times_remaining == 0
            break
        end
    end

    if isempty(time_series)
        throw(ArgumentError("did not find a time_series matching the requested parameters"))
    end

    @assert times_remaining == 0

    # Run the type-specific constructor that concatenates time_series.
    return time_series_type(time_series)
end

function _make_time_series(
    ::Type{T},
    component::InfrastructureSystemsComponent,
    start_index::Int,
    len::Int,
    initial_time::Dates.DateTime,
    label::AbstractString,
) where {T <: TimeSeriesMetadata}
    container = get_time_series_container(component)
    ts_metadata = get_time_series(T, container, label)
    ta = get_time_series(
        _get_time_series_storage(component),
        get_time_series_uuid(ts_metadata);
        index = start_index,
        len = len,
    )
    return make_time_series_data(ts_metadata, ta)
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
    label::AbstractString,
    horizon::Union{Nothing, Int} = nothing,
) where {T <: AbstractTimeSeriesData}
    if horizon === nothing
        time_series = get_time_series(T, component, initial_time, label)
    else
        time_series = get_time_series(T, component, initial_time, label, horizon)
    end

    return get_time_series_array(component, time_series)
end

function get_time_series_array(
    component::InfrastructureSystemsComponent,
    time_series::AbstractTimeSeriesData,
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
    label::AbstractString,
    horizon::Union{Nothing, Int} = nothing,
) where {T <: AbstractTimeSeriesData}
    return (TimeSeries.timestamp ∘ get_time_series_array)(
        T,
        component,
        initial_time,
        label,
        horizon,
    )
end

function get_time_series_timestamps(
    component::InfrastructureSystemsComponent,
    time_series::AbstractTimeSeriesData,
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
    label::AbstractString,
    horizon::Union{Nothing, Int} = nothing,
) where {T <: AbstractTimeSeriesData}
    return (TimeSeries.values ∘ get_time_series_array)(
        T,
        component,
        initial_time,
        label,
        horizon,
    )
end

function get_time_series_values(
    component::InfrastructureSystemsComponent,
    time_series::AbstractTimeSeriesData,
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
) where {T <: AbstractTimeSeriesData}
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
    label::AbstractString,
) where {T <: AbstractTimeSeriesData}
    if !has_time_series(component)
        throw(ArgumentError("$(typeof(component)) does not have time_series"))
    end
    return get_time_series_initial_times(
        time_series_data_to_metadata(T),
        get_time_series_container(component),
        label,
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
Generates all possible initial times for the stored time_series. This should return the same
result regardless of whether the time_series have been stored as one contiguous array or
chunks of contiguous arrays, such as one 365-day time_series vs 365 one-day time_series.

Throws ArgumentError if there are no time_series stored, interval is not a multiple of the
system's time_series resolution, or if the stored time_series have overlapping timestamps.

# Arguments
- `component::InfrastructureSystemsComponent`: Component containing time_series.
- `interval::Dates.Period`: Amount of time in between each initial time.
- `horizon::Int`: Length of each time_series array.
- `initial_time::Union{Nothing, Dates.DateTime}=nothing`: Start with this time. If nothing,
  use the first initial time.
"""
function generate_initial_times(
    component::InfrastructureSystemsComponent,
    interval::Dates.Period,
    horizon::Int;
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
)
    # This throws if no time_series.
    existing_initial_times = get_time_series_initial_times(component)

    first_time_series = iterate(get_time_series_multiple(TimeSeriesMetadata, component))[1]
    resolution = Dates.Second(get_resolution(first_time_series))
    sys_horizon = get_horizon(first_time_series)

    first_initial_time, total_horizon = check_contiguous_time_series(
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
Return true if the time_series are contiguous.
"""
function are_time_series_contiguous(component::InfrastructureSystemsComponent)
    existing_initial_times = get_time_series_initial_times(component)
    first_initial_time = existing_initial_times[1]

    first_time_series = iterate(get_time_series_multiple(TimeSeriesMetadata, component))[1]
    resolution = Dates.Second(get_resolution(first_time_series))
    horizon = get_horizon(first_time_series)
    total_horizon = horizon * length(existing_initial_times)

    return _are_time_series_contiguous(existing_initial_times, resolution, horizon)
end

function _are_time_series_contiguous(initial_times, resolution, horizon)
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
Throws ArgumentError if the time_series are not in consecutive order.
"""
function check_contiguous_time_series(
    component::InfrastructureSystemsComponent,
    existing_initial_times,
    resolution::Dates.Period,
    horizon::Int,
)
    if !_are_time_series_contiguous(existing_initial_times, resolution, horizon)
        throw(ArgumentError("generate_initial_times is not allowed with overlapping timestamps"))
    end

    first_initial_time = existing_initial_times[1]
    total_horizon = horizon * length(existing_initial_times)
    return first_initial_time, total_horizon
end

"""
Efficiently add all time_series in one component to another by copying the underlying
references.

# Arguments
- `dst::InfrastructureSystemsComponent`: Destination component
- `src::InfrastructureSystemsComponent`: Source component
- `label_mapping::Dict = nothing`: Optionally map src labels to different dst labels.
  If provided and src has a time_series with a label not present in label_mapping, that
  time_series will not copied. If label_mapping is nothing then all time_series will be
  copied with src's labels.
- `scaling_factor_multiplier_mapping::Dict = nothing`: Optionally map src multipliers to
  different dst multipliers.  If provided and src has a time_series with a multiplier not
  present in scaling_factor_multiplier_mapping, that time_series will not copied. If
  scaling_factor_multiplier_mapping is nothing then all time_series will be copied with
  src's multipliers.
"""
function copy_time_series!(
    dst::InfrastructureSystemsComponent,
    src::InfrastructureSystemsComponent;
    label_mapping::Union{Nothing, Dict{String, String}} = nothing,
    scaling_factor_multiplier_mapping::Union{Nothing, Dict{String, String}} = nothing,
)
    for ts_metadata in get_time_series_multiple(TimeSeriesMetadata, src)
        label = get_label(ts_metadata)
        new_label = label
        if !isnothing(label_mapping)
            new_label = get(label_mapping, label, nothing)
            if isnothing(new_label)
                @debug "Skip copying ts_metadata" label
                continue
            end
            @debug "Copy ts_metadata with" new_label
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
        set_label!(new_time_series, new_label)
        set_scaling_factor_multiplier!(new_time_series, new_multiplier)
        add_time_series!(dst, new_time_series)
        storage = _get_time_series_storage(dst)
        if isnothing(storage)
            throw(ArgumentError("component does not have time series storage"))
        end
        ts_uuid = get_time_series_uuid(ts_metadata)
        add_time_series_reference!(storage, get_uuid(dst), new_label, ts_uuid)
    end
end

function get_time_series_keys(component::InfrastructureSystemsComponent)
    return keys(get_time_series_container(component).data)
end

function get_time_series_labels(
    ::Type{T},
    component::InfrastructureSystemsComponent,
    initial_time::Dates.DateTime,
) where {T <: AbstractTimeSeriesData}
    return get_time_series_labels(
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
    time_series::AbstractTimeSeriesData,
)
    storage = _get_time_series_storage(component)
    return get_time_series(storage, get_time_series_uuid(time_series))
end

function get_time_series_uuids(component::InfrastructureSystemsComponent)
    container = get_time_series_container(component)

    return [
        (get_time_series_uuid(container.data[key]), key.label)
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
Returns an iterator of AbstractTimeSeriesData instances attached to the component.

Note that passing a filter function can be much slower than the other filtering parameters
because it reads time series data from media.

Call `collect` on the result to get an array.

# Arguments
- `component::InfrastructureSystemsComponent`: component from which to get time_series
- `filter_func = nothing`: Only return time_series for which this returns true.
- `type = nothing`: Only return time_series with this type.
- `initial_time = nothing`: Only return time_series matching this value.
- `label = nothing`: Only return time_series matching this value.
"""
function get_time_series_multiple(
    component::InfrastructureSystemsComponent,
    filter_func = nothing;
    type = nothing,
    initial_time = nothing,
    label = nothing,
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
            if !isnothing(label) && key.label != label
                continue
            end
            ts_metadata = container.data[key]
            ta = get_time_series(storage, get_time_series_uuid(ts_metadata))
            ts_data = make_time_series_data(ts_metadata, ta)
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
        for (uuid, label) in get_time_series_uuids(component)
            remove_time_series!(storage, uuid, get_uuid(component), label)
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
    # Initial times for each label must be identical.
    initial_times = Dict{String, Vector{Dates.DateTime}}()
    for key in keys(get_time_series_container(component).data)
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

function _get_time_series_storage(component::InfrastructureSystemsComponent)
    container = get_time_series_container(component)
    if isnothing(container)
        return nothing
    end

    return container.time_series_storage
end
