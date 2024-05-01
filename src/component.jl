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
Return true if the component has supplemental attributes of the given type.
"""
function has_supplemental_attributes(
    component::InfrastructureSystemsComponent,
    ::Type{T},
) where {T <: SupplementalAttribute}
    associations = _get_supplemental_attribute_associations(component)
    isnothing(associations) && return false
    return has_association(associations, component, T)
end

has_supplemental_attributes(
    T::Type{<:SupplementalAttribute},
    x::InfrastructureSystemsComponent,
) = has_supplemental_attributes(x, T)

"""
Return true if the component has supplemental attributes.
"""
function has_supplemental_attributes(component::InfrastructureSystemsComponent)
    associations = _get_supplemental_attribute_associations(component)
    isnothing(associations) && return false
    return has_association(associations, component)
end

function clear_supplemental_attributes!(component::InfrastructureSystemsComponent)
    mgr = _get_supplemental_attributes_manager(component)
    isnothing(mgr) && return
    for uuid in list_associated_supplemental_attribute_uuids(mgr.associations, component)
        attribute = get_supplemental_attribute(mgr, uuid)
        remove_supplemental_attribute!(mgr, component, attribute)
    end
    @debug "Cleared attributes in $(summary(component))."
    return
end

"""
Return a Vector of supplemental_attributes. T can be concrete or abstract.

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
    return _get_supplemental_attributes(T, component)
end

function get_supplemental_attributes(component::InfrastructureSystemsComponent)
    return _get_supplemental_attributes(nothing, component)
end

function _get_supplemental_attributes(
    supplemental_attribute_type::Union{Nothing, Type{<:SupplementalAttribute}},
    component::InfrastructureSystemsComponent,
)
    mgr = _get_supplemental_attributes_manager(component)
    attr_type = if isnothing(supplemental_attribute_type)
        SupplementalAttribute
    else
        supplemental_attribute_type
    end
    isnothing(mgr) && return attr_type[]
    return attr_type[
        get_supplemental_attribute(mgr, x) for
        x in list_associated_supplemental_attribute_uuids(
            mgr.associations,
            component;
            attribute_type = supplemental_attribute_type,
        )
    ]
end

function get_supplemental_attributes(
    filter_func::Function,
    ::Type{T},
    component::InfrastructureSystemsComponent,
) where {T <: SupplementalAttribute}
    return _get_supplemental_attributes(filter_func, T, component)
end

function get_supplemental_attributes(
    filter_func::Function,
    component::InfrastructureSystemsComponent,
)
    return _get_supplemental_attributes(filter_func, nothing, component)
end

function _get_supplemental_attributes(
    filter_func::Function,
    supplemental_attribute_type::Union{Nothing, Type{<:SupplementalAttribute}},
    component::InfrastructureSystemsComponent,
)
    attr_type = if isnothing(supplemental_attribute_type)
        SupplementalAttribute
    else
        supplemental_attribute_type
    end
    mgr = _get_supplemental_attributes_manager(component)
    isnothing(mgr) && return [attr_type]
    attrs = Vector{attr_type}()
    for uuid in list_associated_supplemental_attribute_uuids(
        mgr.associations,
        component;
        attribute_type = supplemental_attribute_type,
    )
        attribute = get_supplemental_attribute(mgr, uuid)
        if filter_func(attribute)
            push!(attrs, attribute)
        end
    end

    return attrs
end

function get_supplemental_attribute(
    component::InfrastructureSystemsComponent,
    uuid::Base.UUID,
)
    mgr = _get_supplemental_attributes_manager(component)
    isnothing(mgr) &&
        error("$(summary(component)) does not have supplemental attributes")
    return get_supplemental_attribute(mgr, uuid)
end

function _get_supplemental_attributes_manager(component::InfrastructureSystemsComponent)
    !supports_supplemental_attributes(component) && return nothing
    isnothing(get_internal(component).shared_system_references) && return nothing
    return get_internal(component).shared_system_references.supplemental_attribute_manager
end

function _get_supplemental_attribute_associations(component::InfrastructureSystemsComponent)
    mgr = _get_supplemental_attributes_manager(component)
    isnothing(mgr) && return nothing
    return mgr.associations
end
