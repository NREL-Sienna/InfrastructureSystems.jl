

#function serialize(container::SupplementalAttributesContainer)
#    return [serialize(uuid) for attrs in values(container) for uuid in keys(attrs)]
#end
#
#function deserialize(
#    ::Type{SupplementalAttributesContainer},
#    uuids::Vector,
#    system_attributes::Dict{Base.UUID, <:SupplementalAttribute},
#)
#    container = SupplementalAttributesContainer()
#    for uuid_dict in uuids
#        uuid = deserialize(Base.UUID, uuid_dict)
#        attribute = system_attributes[uuid]
#        type = typeof(attribute)
#        if !haskey(container, type)
#            container[type] = Dict{Base.UUID, SupplementalAttribute}()
#        end
#        if haskey(container[type], uuid)
#            error(
#                "Bug: component supplemental attribute container already has uuid = $uuid",
#            )
#        end
#        container[type][uuid] = attribute
#    end
#
#    return container
#end
