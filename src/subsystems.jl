"""
Add a new subsystem to the system.
"""
function add_subsystem!(data::SystemData, subsystem_name::String)
    if haskey(data.subsystems, subsystem_name)
        throw(ArgumentError("There is already a subsystem with name = $subsystem_name."))
    end

    data.subsystems[subsystem_name] = Set{Base.UUID}()
    @debug "Added subystem $subsystem_name" _group = LOG_GROUP_SYSTEM
    return
end

"""
Return an iterator of all subsystem names in the system.
"""
function get_subsystems(data::SystemData)
    return keys(data.subsystems)
end

"""
Return the number of subsystems in the system.
"""
function get_num_subsystems(data::SystemData)
    return length(data.subsystems)
end

"""
Remove a subsystem from the system.

Throws ArgumentError if the subsystem name is not stored.
"""
function remove_subsystem!(data::SystemData, subsystem_name::String)
    _throw_if_not_stored(data, subsystem_name)
    container = pop!(data.subsystems, subsystem_name)
    @debug "Removed subystem $subsystem_name" length(container) _group = LOG_GROUP_SYSTEM
    return
end

"""
Add a component to a subsystem.
"""
function add_component_to_subsystem!(
    data::SystemData,
    subsystem_name::String,
    component::InfrastructureSystemsComponent,
)
    if !has_component(data, component)
        throw(ArgumentError("$(summary(component)) is not stored in the system"))
    end
    _throw_if_not_stored(data, subsystem_name)

    container = data.subsystems[subsystem_name]
    uuid = get_uuid(component)
    if uuid in container
        throw(
            ArgumentError(
                "Subsystem $subsystem_name already contains $(summary(component))",
            ),
        )
    end

    push!(container, uuid)
    @debug "Added $(summary(component)) to subystem $subsystem_name" _group =
        LOG_GROUP_SYSTEM
    return
end

"""
Return a Generator of all components in the subsystem.

Throws ArgumentError if the subsystem name is not stored.
"""
function get_subsystem_components(data::SystemData, subsystem_name::String)
    _throw_if_not_stored(data, subsystem_name)
    return (get_component(data, x) for x in data.subsystems[subsystem_name])
end

function get_component_uuids(data::SystemData, subsystem_name::String)
    _throw_if_not_stored(data, subsystem_name)
    return data.subsystems[subsystem_name]
end

"""
Remove a component from a subsystem.

Throws ArgumentError if the subsystem name or component is not stored.
"""
function remove_component_from_subsystem!(
    data::SystemData,
    subsystem_name::String,
    component::InfrastructureSystemsComponent,
)
    if !has_component(data, subsystem_name, component)
        throw(
            ArgumentError("Subsystem $subsystem_name does not have $(summary(component))"),
        )
    end

    pop!(data.subsystems[subsystem_name], get_uuid(component))
    @debug "Removed $(summary(component)) from subystem $subsystem_name" _group =
        LOG_GROUP_SYSTEM
    return
end

function remove_component_from_subsystems!(
    data::SystemData,
    component::InfrastructureSystemsComponent,
)
    uuid = get_uuid(component)
    for (subsystem_name, uuids) in data.subsystems
        pop!(uuids, uuid, nothing)
        @debug "Removed $(summary(component)) from subystem $subsystem_name" _group =
            LOG_GROUP_SYSTEM
    end
    return
end

"""
Return true if the component is in the subsystem.
"""
function has_component(
    data::SystemData,
    subsystem_name::String,
    component::InfrastructureSystemsComponent,
)
    _throw_if_not_stored(data, subsystem_name)
    return get_uuid(component) in data.subsystems[subsystem_name]
end

"""
Return a Vector of subsystem names that contain the component.
"""
function get_assigned_subsystems(
    data::SystemData,
    component::InfrastructureSystemsComponent,
)
    uuid = get_uuid(component)
    return [k for (k, v) in data.subsystems if uuid in v]
end

"""
Return true if the component is assigned to any subsystems.
"""
function is_assigned_to_subsystem(
    data::SystemData,
    component::InfrastructureSystemsComponent,
)
    uuid = get_uuid(component)
    for uuids in values(data.subsystems)
        if uuid in uuids
            return true
        end
    end

    return false
end

"""
Return true if the component is assigned to the subsystem.
"""
function is_assigned_to_subsystem(
    data::SystemData,
    component::InfrastructureSystemsComponent,
    subsystem_name::String,
)
    _throw_if_not_stored(data, subsystem_name)
    return get_uuid(component) in data.subsystems[subsystem_name]
end

function _throw_if_not_stored(data::SystemData, subsystem_name::String)
    if !haskey(data.subsystems, subsystem_name)
        throw(ArgumentError("There is no subsystem with name = $subsystem_name."))
    end
end
