"""
This function must be called when a component is removed from a system.
"""
function prepare_for_removal!(component::InfrastructureSystemsComponent)
    clear_time_series!(component)
    set_time_series_manager!(component, nothing)
    @debug "cleared all time series data from" _group = LOG_GROUP_SYSTEM get_name(component)
    return
end

"""
Returns an iterator of TimeSeriesData instances attached to the component.

Note that passing a filter function can be much slower than the other filtering parameters
because it reads time series data from media.

Call `collect` on the result to get an array.

# Arguments

  - `owner::InfrastructureSystemsComponent`: component or attribute from which to get time_series
  - `filter_func = nothing`: Only return time_series for which this returns true.
  - `type = nothing`: Only return time_series with this type.
  - `name = nothing`: Only return time_series matching this value.
"""
function get_time_series_multiple(
    owner::TimeSeriesOwners,
    filter_func = nothing;
    type = nothing,
    name = nothing,
)
    throw_if_does_not_support_time_series(owner)
    mgr = get_time_series_manager(owner)
    # This is true when the component is not part of a system.
    isnothing(mgr) && return ()
    storage = get_time_series_storage(owner)

    Channel() do channel
        for metadata in list_metadata(mgr, owner; time_series_type = type, name = name)
            ts = deserialize_time_series(
                isnothing(type) ? time_series_metadata_to_data(metadata) : type,
                storage,
                metadata,
                UnitRange(1, length(metadata)),
                UnitRange(1, get_count(metadata)),
            )
            if !isnothing(filter_func) && !filter_func(ts)
                continue
            end
            put!(channel, ts)
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
    horizon::Int,
    interval::Dates.Period,
) where {T <: DeterministicSingleTimeSeries}
    mgr = get_time_series_manager(component)
    metadata_to_add = []
    for metadata in list_metadata(mgr, component; time_series_type = SingleTimeSeries)
        params = _get_single_time_series_transformed_parameters(
            metadata,
            T,
            horizon,
            interval,
        )
        check_params_compatibility(mgr.metadata_store, params)
        new_metadata = DeterministicMetadata(;
            name = get_name(metadata),
            resolution = get_resolution(metadata),
            initial_timestamp = params.initial_timestamp,
            interval = params.interval,
            count = params.count,
            time_series_uuid = get_time_series_uuid(metadata),
            horizon = params.horizon,
            time_series_type = DeterministicSingleTimeSeries,
            scaling_factor_multiplier = get_scaling_factor_multiplier(metadata),
            internal = get_internal(metadata),
        )
        push!(metadata_to_add, new_metadata)
    end

    isempty(metadata_to_add) && return false

    for new_metadata in metadata_to_add
        add_metadata!(mgr.metadata_store, component, new_metadata)
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
    mgr = get_time_series_manager(component)
    for metadata in list_metadata(mgr, component; time_series_type = SingleTimeSeries)
        return _get_single_time_series_transformed_parameters(
            metadata,
            T,
            horizon,
            interval,
        )
    end

    return
end

function _get_single_time_series_transformed_parameters(
    metadata::SingleTimeSeriesMetadata,
    ::Type{T},
    horizon::Int,
    interval::Dates.Period,
) where {T <: Forecast}
    resolution = get_resolution(metadata)
    len = length(metadata)
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

    initial_timestamp = get_initial_timestamp(metadata)
    count = get_forecast_window_count(initial_timestamp, interval, resolution, len, horizon)
    return ForecastParameters(;
        initial_timestamp = initial_timestamp,
        count = count,
        horizon = horizon,
        interval = interval,
        resolution = resolution,
    )
end

function assign_new_uuid_internal!(component::InfrastructureSystemsComponent)
    old_uuid = get_uuid(component)
    new_uuid = make_uuid()
    mgr = get_time_series_manager(component)
    if !isnothing(mgr)
        replace_component_uuid!(mgr.metadata_store, old_uuid, new_uuid)
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
