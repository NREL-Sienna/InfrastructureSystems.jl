struct SupplementalAttributes <: InfrastructureSystemsContainer
    data::SupplementalAttributesContainer
    time_series_storage::TimeSeriesStorage
end

get_member_string(::SupplementalAttributes) = "supplemental attributes"

function SupplementalAttributes(time_series_storage::TimeSeriesStorage)
    return SupplementalAttributes(SupplementalAttributesContainer(), time_series_storage)
end

function add_supplemental_attribute!(
    supplemental_attributes::SupplementalAttributes,
    component::InfrastructureSystemsComponent,
    supplemental_attribute::SupplementalAttribute;
    kwargs...,
)
    try
        attach_component!(supplemental_attribute, component)
        attach_supplemental_attribute!(component, supplemental_attribute)
        _add_supplemental_attribute!(
            supplemental_attributes,
            supplemental_attribute;
            kwargs...,
        )
    catch e
        detach_component!(supplemental_attribute, component)
        detach_supplemental_attribute!(component, supplemental_attribute)
        rethrow(e)
    end
    return
end

function _add_supplemental_attribute!(
    supplemental_attributes::SupplementalAttributes,
    supplemental_attribute::T;
    allow_existing_time_series = false,
) where {T <: SupplementalAttribute}
    if !isconcretetype(T)
        throw(ArgumentError("add_supplemental_attribute! only accepts concrete types"))
    end

    supplemental_attribute_uuid = get_uuid(supplemental_attribute)
    if isempty(get_component_uuids(supplemental_attribute))
        throw(
            ArgumentError(
                "SupplementalAttribute type $T with UUID $supplemental_attribute_uuid is not attached to any component",
            ),
        )
    end

    if !haskey(supplemental_attributes.data, T)
        supplemental_attributes.data[T] = Dict{UUIDs.UUID, T}()
    elseif haskey(supplemental_attributes.data[T], supplemental_attribute_uuid)
        @debug "SupplementalAttribute type $T with UUID $supplemental_attribute_uuid already stored" _group =
            LOG_GROUP_SYSTEM
        return
    end

    if !allow_existing_time_series && has_time_series(supplemental_attribute)
        throw(
            ArgumentError(
                "cannot add an supplemental_attribute with time_series: $supplemental_attribute",
            ),
        )
    end

    set_time_series_storage!(
        supplemental_attribute,
        supplemental_attributes.time_series_storage,
    )
    supplemental_attributes.data[T][supplemental_attribute_uuid] = supplemental_attribute
    return
end

"""
Iterates over all supplemental_attributes.

# Examples

```Julia
for supplemental_attribute in iterate_supplemental_attributes(obj)
    @show supplemental_attribute
end
```
"""
function iterate_supplemental_attributes(supplemental_attributes::SupplementalAttributes)
    iterate_container(supplemental_attributes)
end

function iterate_supplemental_attributes_with_time_series(
    supplemental_attributes::SupplementalAttributes,
)
    iterate_container_with_time_series(supplemental_attributes)
end

"""
Returns the total number of stored supplemental_attributes
"""
function get_num_supplemental_attributes(supplemental_attributes::SupplementalAttributes)
    return get_num_members(supplemental_attributes)
end

"""
Removes all supplemental_attributes from the system.
"""
function clear_supplemental_attributes!(supplemental_attributes::SupplementalAttributes)
    for type in collect(keys(supplemental_attributes.data))
        remove_supplemental_attributes!(type, supplemental_attributes)
    end
end

function remove_supplemental_attribute!(
    supplemental_attributes::SupplementalAttributes,
    supplemental_attribute::T,
) where {T <: SupplementalAttribute}
    if !isempty(get_component_uuids(supplemental_attribute))
        throw(
            ArgumentError(
                "SupplementalAttribute type $T with uuid $(get_uuid(supplemental_attribute)) still attached to devices $(get_component_uuids(supplemental_attribute))",
            ),
        )
    end

    pop!(supplemental_attributes.data[T], get_uuid(supplemental_attribute))
    if isempty(supplemental_attributes.data[T])
        pop!(supplemental_attributes.data, T)
    end
    clear_time_series_storage!(supplemental_attribute)
    return
end

"""
Remove all supplemental_attributes of type T.

Throws ArgumentError if the type is not stored.
"""
function remove_supplemental_attributes!(
    ::Type{T},
    supplemental_attributes::SupplementalAttributes,
) where {T <: SupplementalAttribute}
    if !haskey(supplemental_attributes.data, T)
        throw(ArgumentError("supplemental_attribute type $T is not stored"))
    end

    _supplemental_attributes = pop!(supplemental_attributes.data, T)
    for supplemental_attribute in values(_supplemental_attributes)
        prepare_for_removal!(supplemental_attribute)
    end

    @debug "Removed all supplemental_attributes of type $T" _group = LOG_GROUP_SYSTEM T
    return values(_supplemental_attributes)
end

# TODO: This function could be merged with the getter for components if no additional functionality is needed
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
    filter_func::Function,
    ::Type{T},
    supplemental_attributes::SupplementalAttributes,
) where {T <: SupplementalAttribute}
    return get_supplemental_attributes(filter_func, T, supplemental_attributes.data)
end

function get_supplemental_attributes(
    ::Type{T},
    supplemental_attributes::SupplementalAttributes,
) where {T <: SupplementalAttribute}
    return get_supplemental_attributes(T, supplemental_attributes.data)
end

function get_supplemental_attribute(attributes::SupplementalAttributes, uuid::Base.UUID)
    return get_supplemental_attribute(attributes.data, uuid)
end

function serialize(attributes::SupplementalAttributes)
    return [serialize(y) for x in values(attributes.data) for y in values(x)]
end

function deserialize(
    ::Type{SupplementalAttributes},
    data::Vector,
    time_series_storage::TimeSeriesStorage,
)
    attributes = SupplementalAttributesByType()
    for attr_dict in data
        type = get_type_from_serialization_metadata(get_serialization_metadata(attr_dict))
        if !haskey(attributes, type)
            attributes[type] =
                Dict{UUIDs.UUID, SupplementalAttribute}()
        end
        attr = deserialize(type, attr_dict)
        uuid = get_uuid(attr)
        if haskey(attributes[type], uuid)
            error("Bug: duplicate UUID in attributes container: type=$type uuid=$uuid")
        end
        attributes[type][uuid] = attr
        @debug "Deserialized $(summary(attr))" _group = LOG_GROUP_SERIALIZATION
    end

    return SupplementalAttributes(
        SupplementalAttributesContainer(attributes),
        time_series_storage,
    )
end
