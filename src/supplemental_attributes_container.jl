"""
All components must include a field of this type in order to store supplemental attributes.
"""
struct SupplementalAttributesContainer
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
Base.values(x::SupplementalAttributesContainer) = values(x.data)
Base.delete!(x::SupplementalAttributesContainer, key) = delete!(x.data, key)
Base.empty!(x::SupplementalAttributesContainer) = empty!(x.data)
Base.setindex!(x::SupplementalAttributesContainer, val, key) = setindex!(x.data, val, key)
Base.pop!(x::SupplementalAttributesContainer, key) = pop!(x.data, key)

function serialize(container::SupplementalAttributesContainer)
    return [serialize(uuid) for attrs in values(container) for uuid in keys(attrs)]
end

function deserialize(
    ::Type{SupplementalAttributesContainer},
    uuids::Vector,
    system_attributes::Dict{Base.UUID, <:InfrastructureSystemsSupplementalAttribute},
)
    container = SupplementalAttributesContainer()
    for uuid_dict in uuids
        uuid = deserialize(Base.UUID, uuid_dict)
        attribute = system_attributes[uuid]
        type = typeof(attribute)
        if !haskey(container, type)
            container[type] = Dict{Base.UUID, InfrastructureSystemsSupplementalAttribute}()
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
