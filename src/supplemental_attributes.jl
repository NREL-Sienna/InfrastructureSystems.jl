const SupplementalAttributesContainer =
    Dict{DataType, Set{<:InfrastructureSystemsSupplementalAttribute}}
const SupplementalAttributesByType =
    Dict{DataType, Dict{UUIDs.UUID, <:InfrastructureSystemsSupplementalAttribute}}

struct SupplementalAttributes <: InfrastructureSystemsContainer
    data::SupplementalAttributesByType
    time_series_storage::TimeSeriesStorage
end

get_display_string(::SupplementalAttributes) = "SupplementalAttributes"

function SupplementalAttributes(time_series_storage::TimeSeriesStorage)
    return SupplementalAttributes(SupplementalAttributesByType(), time_series_storage)
end

function add_supplemental_attribute!(
    supplemental_attributes::SupplementalAttributes,
    component::InfrastructureSystemsComponent,
    supplemental_attribute::InfrastructureSystemsSupplementalAttribute;
    kwargs...,
)
    attach_supplemental_attribute!(component, supplemental_attribute)
    _add_supplemental_attribute!(supplemental_attributes, supplemental_attribute; kwargs...)
    return
end

function _add_supplemental_attribute!(
    supplemental_attributes::SupplementalAttributes,
    supplemental_attribute::T;
    allow_existing_time_series=false,
) where {T <: InfrastructureSystemsSupplementalAttribute}
    if !isconcretetype(T)
        throw(ArgumentError("add_supplemental_attribute! only accepts concrete types"))
    end

    supplemental_attribute_uuid = get_uuid(supplemental_attribute)
    if isempty(get_components_uuids(supplemental_attribute))
        throw(
            ArgumentError(
                "SupplementalAttribute type $T with UUID $supplemental_attribute_uuid is not attached to any component",
            ),
        )
    end

    if !haskey(supplemental_attributes.data, T)
        supplemental_attributes.data[T] = Dict{UUIDs.UUID, T}()
    elseif haskey(supplemental_attributes.data[T], supplemental_attribute_uuid)
        @debug "SupplementalAttribute type $T with UUID $supplemental_attribute_uuid already stored"
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
Check to see if supplemental_attribute exists.
"""
function has_supplemental_attribute(
    ::Type{T},
    component::U,
) where {
    T <: InfrastructureSystemsSupplementalAttribute,
    U <: InfrastructureSystemsComponent,
}
    if !isconcretetype(T)
        supplemental_attributes = [
            v for
            v in values(get_supplemental_attributes_container(component)) if !isempty(v)
        ]
        return !isempty(supplemental_attributes)
    end
    supplemental_attributes = get_supplemental_attributes_container(component)
    !haskey(supplemental_attributes, T) && return false
    return !isempty(supplemental_attributes[T])
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
    for type_ in collect(keys(supplemental_attributes.data))
        remove_supplemental_attributes!(type_, supplemental_attributes)
    end
end

function remove_supplemental_attribute!(
    supplemental_attributes::SupplementalAttributes,
    supplemental_attribute::T,
) where {T <: InfrastructureSystemsSupplementalAttribute}
    if !isempty(get_components_uuids(supplemental_attribute))
        throw(
            ArgumentError(
                "SupplementalAttribute type $T with uuid $(get_uuid(supplemental_attribute)) still attached to devices $(get_components_uuids(supplemental_attribute))",
            ),
        )
    end

    pop!(supplemental_attributes.data[T], get_uuid(supplemental_attribute))
    return
end

"""
Remove all supplemental_attributes of type T.

Throws ArgumentError if the type is not stored.
"""
function remove_supplemental_attributes!(
    ::Type{T},
    supplemental_attributes::SupplementalAttributes,
) where {T <: InfrastructureSystemsSupplementalAttribute}
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
    supplemental_attributes::SupplementalAttributes,
    filter_func::Union{Nothing, Function}=nothing,
) where {T <: InfrastructureSystemsSupplementalAttribute}
    if isconcretetype(T)
        _supplemental_attributes = get(supplemental_attributes.data, T, nothing)
        if !isnothing(filter_func) && !isnothing(_supplemental_attributes)
            _filter_func = x -> filter_func(x.second)
            _supplemental_attributes =
                values(filter(_filter_func, _supplemental_attributes))
        end
        if isnothing(_supplemental_attributes)
            iter = FlattenIteratorWrapper(T, Vector{Base.ValueIterator}([]))
        else
            iter = FlattenIteratorWrapper(
                T,
                Vector{Base.ValueIterator}([values(_supplemental_attributes)]),
            )
        end
    else
        types = [x for x in keys(supplemental_attributes.data) if x <: T]
        if isnothing(filter_func)
            _supplemental_attributes =
                [values(supplemental_attributes.data[x]) for x in types]
        else
            _filter_func = x -> filter_func(x.second)
            _supplemental_attributes = [
                values(filter(_filter_func, supplemental_attributes.data[x])) for x in types
            ]
        end
        iter = FlattenIteratorWrapper(T, _supplemental_attributes)
    end

    @assert_op eltype(iter) == T
    return iter
end
