const SupplementalAttributesByType =
    Dict{DataType, Dict{UUIDs.UUID, <:SupplementalAttribute}}

"""
All components must include a field of this type in order to store supplemental attributes.
"""
struct SupplementalAttributesContainer <: InfrastructureSystemsType
    data::SupplementalAttributesByType
end

function SupplementalAttributesContainer(; data = SupplementalAttributesByType())
    return SupplementalAttributesContainer(data)
end

Base.getindex(x::SupplementalAttributesContainer, key) = getindex(x.data, key)
Base.haskey(x::SupplementalAttributesContainer, key) = haskey(x.data, key)
Base.isempty(x::SupplementalAttributesContainer) = isempty(x.data)
Base.iterate(x::SupplementalAttributesContainer, args...) = iterate(x.data, args...)
Base.length(x::SupplementalAttributesContainer) = length(x.data)
Base.keys(x::SupplementalAttributesContainer) = keys(x.data)
Base.values(x::SupplementalAttributesContainer) = values(x.data)
Base.delete!(x::SupplementalAttributesContainer, key) = delete!(x.data, key)
Base.empty!(x::SupplementalAttributesContainer) = empty!(x.data)
Base.setindex!(x::SupplementalAttributesContainer, val, key) = setindex!(x.data, val, key)
Base.pop!(x::SupplementalAttributesContainer, key) = pop!(x.data, key)

function get_supplemental_attributes(
    ::Type{T},
    container::SupplementalAttributesContainer,
) where {T <: SupplementalAttribute}
    return iterate_instances(T, container.data, nothing)
end

function get_supplemental_attributes(
    filter_func::Function,
    ::Type{T},
    container::SupplementalAttributesContainer,
) where {T <: SupplementalAttribute}
    return iterate_instances(filter_func, T, container.data, nothing)
end

function get_supplemental_attribute(
    container::SupplementalAttributesContainer,
    uuid::Base.UUID,
)
    for attr_dict in values(container.data)
        attribute = get(attr_dict, uuid, nothing)
        if !isnothing(attribute)
            return attribute
        end
    end

    throw(ArgumentError("No attribute with UUID=$uuid is stored"))
end

function serialize(container::SupplementalAttributesContainer)
    return [serialize(uuid) for attrs in values(container) for uuid in keys(attrs)]
end

function deserialize(
    ::Type{SupplementalAttributesContainer},
    uuids::Vector,
    system_attributes::Dict{Base.UUID, <:SupplementalAttribute},
)
    container = SupplementalAttributesContainer()
    for uuid_dict in uuids
        uuid = deserialize(Base.UUID, uuid_dict)
        attribute = system_attributes[uuid]
        type = typeof(attribute)
        if !haskey(container, type)
            container[type] = Dict{Base.UUID, SupplementalAttribute}()
        end
        if haskey(container[type], uuid)
            error(
                "Bug: component supplemental attribute container already has uuid = $uuid",
            )
        end
        container[type][uuid] = attribute
    end

    return container
end
