function attach_component!(
    attribute::T,
    component::InfrastructureSystemsComponent,
) where {T <: SupplementalAttribute}
    component_uuid = get_uuid(component)

    if component_uuid ∈ get_component_uuids(attribute)
        throw(
            ArgumentError(
                "SupplementalAttribute type $T with UUID $(get_uuid(attribute)) already attached to component $(summary(component))",
            ),
        )
    end

    push!(get_component_uuids(attribute), component_uuid)
    return
end

function detach_component!(
    attribute::SupplementalAttribute,
    component::InfrastructureSystemsComponent,
)
    delete!(get_component_uuids(attribute), get_uuid(component))
    return
end

"""
Return true if the attribute is attached to at least one component.
"""
function is_attached_to_component(attribute::SupplementalAttribute)
    return !isempty(get_component_uuids(attribute))
end

"""
This function must be called when an attribute is removed from a system.
"""
function prepare_for_removal!(
    attribute::T,
) where {T <: SupplementalAttribute}
    if !isempty(get_component_uuids(attribute))
        throw(
            ArgumentError(
                "attribute type $T with uuid $(get_uuid(attribute)) still attached to a component",
            ),
        )
    end

    clear_time_series!(attribute)
    set_time_series_manager!(attribute, nothing)
    @debug "cleared all time series data from" _group = LOG_GROUP_SYSTEM get_uuid(attribute)
    return
end
