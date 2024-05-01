# TODO DT before merge, rename file to supplemental_attribute_manager.jl

const SupplementalAttributesByType =
    Dict{DataType, Dict{Base.UUID, <:SupplementalAttribute}}

struct SupplementalAttributeManager <: InfrastructureSystemsContainer
    data::SupplementalAttributesByType
    time_series_manager::TimeSeriesManager
    associations::SupplementalAttributeAssociations
end

function SupplementalAttributeManager(
    data::SupplementalAttributesByType,
    time_series_manager::TimeSeriesManager,
)
    return SupplementalAttributeManager(
        data,
        time_series_manager,
        SupplementalAttributeAssociations(get_database(time_series_manager), true),
    )
end

function SupplementalAttributeManager(time_series_manager::TimeSeriesManager)
    return SupplementalAttributeManager(
        SupplementalAttributesByType(),
        time_series_manager,
        SupplementalAttributeAssociations(get_database(time_series_manager), true),
    )
end

get_member_string(::SupplementalAttributeManager) = "supplemental attributes"

function add_supplemental_attribute!(
    mgr::SupplementalAttributeManager,
    component::InfrastructureSystemsComponent,
    attribute::SupplementalAttribute;
    allow_existing_time_series = false,
)
    if has_association(mgr.associations, component, attribute)
        throw(
            ArgumentError(
                "There is already an association between " *
                "$(summary(component)) and $(summary(attribute))",
            ),
        )
    end
    _attach_attribute!(
        mgr,
        attribute;
        allow_existing_time_series = allow_existing_time_series,
    )
    add_association!(mgr.associations, component, attribute)
    return
end

function _attach_attribute!(
    mgr::SupplementalAttributeManager,
    attribute::SupplementalAttribute;
    allow_existing_time_series = false,
)
    is_attached(attribute, mgr) && return

    if !allow_existing_time_series && has_time_series(attribute)
        throw(
            ArgumentError(
                "cannot add an attribute with time_series: $attribute",
            ),
        )
    end

    T = typeof(attribute)
    if !haskey(mgr.data, T)
        mgr.data[T] = Dict{Base.UUID, T}()
    end
    set_shared_system_references!(
        attribute,
        SharedSystemReferences(;
            supplemental_attribute_manager = mgr,
            time_series_manager = mgr.time_series_manager,
        ),
    )
    mgr.data[T][get_uuid(attribute)] = attribute
end

function is_attached(attribute::SupplementalAttribute, mgr::SupplementalAttributeManager)
    T = typeof(attribute)
    !haskey(mgr.data, T) && return false
    _attribute = get(mgr.data[T], get_uuid(attribute), nothing)
    isnothing(_attribute) && return false

    if attribute !== _attribute
        @warn "A attribute with the same UUUID as $(summary(attribute)) is stored in the " *
              "system but is not the same instance."
        return false
    end

    return true
end

function throw_if_not_attached(
    mgr::SupplementalAttributeManager,
    attribute::SupplementalAttribute,
)
    if !is_attached(attribute, mgr)
        throw(ArgumentError("$(summary(attribute)) is not attached to the system"))
    end
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
function iterate_supplemental_attributes(mgr::SupplementalAttributeManager)
    return iterate_container(mgr)
end

"""
Removes all supplemental_attributes from the system.

Ignores whethere attributes are attached to components.
"""
function clear_supplemental_attributes!(mgr::SupplementalAttributeManager)
    for type in collect(keys(mgr.data))
        remove_supplemental_attributes!(mgr, type)
    end

    association_count = get_num_attributes(mgr.associations)
    if association_count != 0
        error(
            "Bug: There are still $association_count supplemental attribute associations after removing all attributes.",
        )
    end
end

function remove_supplemental_attribute!(
    mgr::SupplementalAttributeManager,
    component::InfrastructureSystemsComponent,
    attribute::SupplementalAttribute,
)
    throw_if_not_attached(mgr, attribute)
    remove_association!(mgr.associations, component, attribute)
    if !has_association(mgr.associations, attribute)
        remove_supplemental_attribute!(mgr, attribute)
    end
end

function remove_supplemental_attribute!(
    mgr::SupplementalAttributeManager,
    supplemental_attribute::SupplementalAttribute;
)
    throw_if_not_attached(mgr, supplemental_attribute)
    if has_association(mgr.associations, supplemental_attribute)
        throw(
            ArgumentError(
                "SupplementalAttribute $(summary(supplemental_attribute)) " *
                "is still attached to one or more components",
            ),
        )
    end

    T = typeof(supplemental_attribute)
    pop!(mgr.data[T], get_uuid(supplemental_attribute))
    prepare_for_removal!(supplemental_attribute)
    if isempty(mgr.data[T])
        pop!(mgr.data, T)
    end
    return
end

"""
Remove all supplemental_attributes of type T.

Ignores whethere attributes are attached to components.

Throws ArgumentError if the type is not stored.
"""
function remove_supplemental_attributes!(
    mgr::SupplementalAttributeManager,
    ::Type{T},
) where {T <: SupplementalAttribute}
    if !haskey(mgr.data, T)
        throw(ArgumentError("supplemental_attribute type $T is not stored"))
    end

    _supplemental_attributes = pop!(mgr.data, T)
    for supplemental_attribute in values(_supplemental_attributes)
        prepare_for_removal!(supplemental_attribute)
    end

    remove_associations!(mgr.associations, T)
    @debug "Removed all supplemental_attributes of type $T" _group = LOG_GROUP_SYSTEM T
    return values(_supplemental_attributes)
end

"""
Returns an iterator of supplemental_attributes. T can be concrete or abstract.
Call collect on the result if an array is desired.

# Arguments

  - `T`: supplemental_attribute type
  - `mgr::SupplementalAttributeManager`: SupplementalAttributeManager in the system
  - `filter_func::Union{Nothing, Function} = nothing`: Optional function that accepts a component
    of type T and returns a Bool. Apply this function to each component and only return components
    where the result is true.
"""
function get_supplemental_attributes(
    filter_func::Function,
    ::Type{T},
    mgr::SupplementalAttributeManager,
) where {T <: SupplementalAttribute}
    return iterate_instances(filter_func, T, mgr.data, nothing)
end

function get_supplemental_attributes(
    ::Type{T},
    mgr::SupplementalAttributeManager,
) where {T <: SupplementalAttribute}
    return iterate_instances(T, mgr.data, nothing)
end

function get_supplemental_attribute(mgr::SupplementalAttributeManager, uuid::Base.UUID)
    for attr_dict in values(mgr.data)
        attribute = get(attr_dict, uuid, nothing)
        if !isnothing(attribute)
            return attribute
        end
    end

    throw(ArgumentError("No attribute with UUID=$uuid is stored"))
end

function serialize(mgr::SupplementalAttributeManager)
    return Dict(
        "associations" => to_records(mgr.associations),
        "attributes" => [serialize(y) for x in values(mgr.data) for y in values(x)],
    )
end

function deserialize(
    ::Type{SupplementalAttributeManager},
    data::Dict,
    time_series_manager::TimeSeriesManager,
)
    attributes = SupplementalAttributesByType()
    for attr_dict in data["attributes"]
        type = get_type_from_serialization_metadata(get_serialization_metadata(attr_dict))
        if !haskey(attributes, type)
            attributes[type] =
                Dict{Base.UUID, SupplementalAttribute}()
        end
        attr = deserialize(type, attr_dict)
        uuid = get_uuid(attr)
        if haskey(attributes[type], uuid)
            error("Bug: duplicate UUID in attributes container: type=$type uuid=$uuid")
        end
        attributes[type][uuid] = attr
        @debug "Deserialized $(summary(attr))" _group = LOG_GROUP_SERIALIZATION
    end

    mgr = SupplementalAttributeManager(
        SupplementalAttributesByType(attributes),
        time_series_manager,
    )

    from_records!(mgr.associations, data["associations"])
    return mgr
end
