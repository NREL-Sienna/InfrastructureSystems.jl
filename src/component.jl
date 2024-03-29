"""
This function must be called when a component is removed from a system.
"""
function prepare_for_removal!(component::InfrastructureSystemsComponent)
    # TimeSeriesContainer can only be part of a component when that component is part of a
    # system.
    clear_time_series_storage!(component)
    set_time_series_storage!(component, nothing)
    clear_time_series!(component)
    @debug "cleared all time series data from" _group = LOG_GROUP_SYSTEM get_name(component)
    return
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
            ts_metadata = container.data[key]
            ts_type = time_series_metadata_to_data(ts_metadata)
            if !isnothing(type) && !(ts_type <: type)
                continue
            end
            if !isnothing(name) && key.name != name
                continue
            end
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

function get_time_series_with_metadata_multiple(
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
            ts_metadata = container.data[key]
            ts_type = time_series_metadata_to_data(ts_metadata)
            if !isnothing(type) && !(ts_type <: type)
                continue
            end
            if !isnothing(name) && key.name != name
                continue
            end
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
            put!(channel, (ts, ts_metadata))
        end
    end
end

"""
Transform all instances of SingleTimeSeries to DeterministicSingleTimeSeries. Do nothing
if the component does not contain any instances.

All required checks must have been completed by the caller.

Return true if a transformation occurs.
"""
function transform_single_time_series_internal!(
    component::InfrastructureSystemsComponent,
    ::Type{T},
    params::TimeSeriesParameters,
) where {T <: DeterministicSingleTimeSeries}
    container = get_time_series_container(component)
    metadata_to_add = []
    for ts_metadata in values(container.data)
        if ts_metadata isa SingleTimeSeriesMetadata
            resolution = get_resolution(ts_metadata)
            _params = _get_single_time_series_transformed_parameters(
                ts_metadata,
                T,
                params.forecast_params.horizon,
                params.forecast_params.interval,
            )
            check_params_compatibility(params, _params)
            new_metadata = DeterministicMetadata(;
                name = get_name(ts_metadata),
                resolution = params.resolution,
                initial_timestamp = params.forecast_params.initial_timestamp,
                interval = params.forecast_params.interval,
                count = params.forecast_params.count,
                time_series_uuid = get_time_series_uuid(ts_metadata),
                horizon = params.forecast_params.horizon,
                time_series_type = DeterministicSingleTimeSeries,
                scaling_factor_multiplier = get_scaling_factor_multiplier(ts_metadata),
                internal = get_internal(ts_metadata),
            )
            push!(metadata_to_add, new_metadata)
        end
    end

    isempty(metadata_to_add) && return false

    for new_metadata in metadata_to_add
        add_time_series!(container, new_metadata)
        @debug "Added $new_metadata." _group = LOG_GROUP_TIME_SERIES
    end

    return true
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

    return
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
        throw(
            ConflictingInputsError("existing length=$len is shorter than horizon=$horizon"),
        )
    end

    max_interval = horizon * resolution
    if len == horizon && interval == max_interval
        interval = Dates.Second(0)
        @warn "There is only one forecast window. Setting interval = $interval"
    elseif interval > max_interval
        throw(
            ConflictingInputsError(
                "interval = $interval is bigger than the max of $max_interval",
            ),
        )
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
    return
end

function set_time_series_storage!(
    component::InfrastructureSystemsComponent,
    storage::Union{Nothing, TimeSeriesStorage},
)
    container = get_time_series_container(component)
    if !isnothing(container)
        set_time_series_storage!(container, storage)
    end
    return
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
    container = get_time_series_container(component)
    ts_metadata = container.data[key]
    ts_type = time_series_metadata_to_data(ts_metadata)
    return get_time_series(
        ts_type,
        component,
        key.name;
        start_time = start_time,
        len = len,
        count = count,
    )
end

function assign_new_uuid_internal!(component::InfrastructureSystemsComponent)
    old_uuid = get_uuid(component)
    new_uuid = make_uuid()
    if has_time_series(component)
        container = get_time_series_container(component)
        # There may be duplicates because of transform operations.
        changed_uuids = Set{Tuple{Base.UUID, String}}()
        for (key, ts_metadata) in container.data
            ts_uuid = get_time_series_uuid(ts_metadata)
            changed_uuid = (ts_uuid, key.name)
            if !in(changed_uuid, changed_uuids)
                replace_component_uuid!(
                    container.time_series_storage,
                    ts_uuid,
                    old_uuid,
                    new_uuid,
                    key.name,
                )
                push!(changed_uuids, changed_uuid)
            end
        end
    end

    set_uuid!(get_internal(component), new_uuid)
    return
end

"""
Attach an attribute to a component.
"""
function attach_supplemental_attribute!(
    component::InfrastructureSystemsComponent,
    attribute::T,
) where {T <: SupplementalAttribute}
    attribute_container = get_supplemental_attributes_container(component)

    if !haskey(attribute_container, T)
        attribute_container[T] = Dict{Base.UUID, T}()
    end

    uuid = get_uuid(attribute)
    if haskey(attribute_container[T], uuid)
        throw(
            ArgumentError(
                "Supplemental attribute $uuid is already attached to $(summary(component))",
            ),
        )
    end
    attribute_container[T][uuid] = attribute
    @debug "SupplementalAttribute type $T with UUID $uuid) stored in component $(summary(component))" _group =
        LOG_GROUP_SYSTEM
    return
end

"""
Return true if the component has supplemental attributes of the given type.
"""
function has_supplemental_attributes(
    ::Type{T},
    component::InfrastructureSystemsComponent,
) where {T <: SupplementalAttribute}
    supplemental_attributes = get_supplemental_attributes_container(component)
    if !isconcretetype(T)
        for (k, v) in supplemental_attributes
            if !isempty(v) && k <: T
                return true
            end
        end
    end
    supplemental_attributes = get_supplemental_attributes_container(component)
    !haskey(supplemental_attributes, T) && return false
    return !isempty(supplemental_attributes[T])
end

"""
Return true if the component has supplemental attributes.
"""
function has_supplemental_attributes(component::InfrastructureSystemsComponent)
    container = get_supplemental_attributes_container(component)
    return !isempty(container)
end

function clear_supplemental_attributes!(component::InfrastructureSystemsComponent)
    container = get_supplemental_attributes_container(component)
    for attributes in values(container)
        for attribute in collect(values(attributes))
            detach_component!(attribute, component)
            detach_supplemental_attribute!(component, attribute)
        end
    end
    empty!(container)
    @debug "Cleared attributes in $(summary(component))."
    return
end

function detach_supplemental_attribute!(
    component::InfrastructureSystemsComponent,
    attribute::T,
) where {T <: SupplementalAttribute}
    container = get_supplemental_attributes_container(component)
    if !haskey(container, T)
        throw(
            ArgumentError(
                "SupplementalAttribute of type $T is not stored in component $(summary(component))",
            ),
        )
    end
    delete!(container[T], get_uuid(attribute))
    if isempty(container[T])
        pop!(container, T)
    end
    return
end

"""
Returns an iterator of supplemental_attributes. T can be concrete or abstract.
Call collect on the result if an array is desired.

# Arguments

  - `T`: supplemental_attribute type
  - `supplemental_attributes::SupplementalAttributes`: SupplementalAttributes in the system
  - `filter_func::Union{Nothing, Function} = nothing`: Optional function that accepts a component
    of type T and returns a Bool. Apply this function to each component and only return components
    where the result is true.
"""
function get_supplemental_attributes(
    ::Type{T},
    component::InfrastructureSystemsComponent,
) where {T <: SupplementalAttribute}
    return get_supplemental_attributes(T, get_supplemental_attributes_container(component))
end

function get_supplemental_attributes(
    filter_func::Function,
    ::Type{T},
    component::InfrastructureSystemsComponent,
) where {T <: SupplementalAttribute}
    return get_supplemental_attributes(
        filter_func,
        T,
        get_supplemental_attributes_container(component),
    )
end

function get_supplemental_attribute(
    component::InfrastructureSystemsComponent,
    uuid::Base.UUID,
)
    return get_supplemental_attribute(
        get_supplemental_attributes_container(component),
        uuid,
    )
end
