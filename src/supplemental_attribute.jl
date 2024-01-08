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
Return true if the attribute has time series data.
"""
function has_time_series(attribute::SupplementalAttribute)
    container = get_time_series_container(attribute)
    return !isnothing(container) && !isempty(container)
end

function clear_time_series_storage!(attribute::SupplementalAttribute)
    storage = _get_time_series_storage(attribute)
    if !isnothing(storage)
        # In the case of Deterministic and DeterministicSingleTimeSeries the UUIDs
        # can be shared.
        uuids = Set{Base.UUID}()
        for (uuid, name) in get_time_series_uuids(attribute)
            if !(uuid in uuids)
                remove_time_series!(storage, uuid, get_uuid(attribute), name)
                push!(uuids, uuid)
            end
        end
    end
end

function set_time_series_storage!(
    attribute::SupplementalAttribute,
    storage::Union{Nothing, TimeSeriesStorage},
)
    container = get_time_series_container(attribute)
    if !isnothing(container)
        set_time_series_storage!(container, storage)
    end
    return
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

    # TimeSeriesContainer can only be part of a component when that component is part of a
    # system.
    clear_time_series_storage!(attribute)
    set_time_series_storage!(attribute, nothing)
    clear_time_series!(attribute)
    @debug "cleared all time series data from" _group = LOG_GROUP_SYSTEM get_uuid(attribute)
    return
end

function _get_time_series_storage(attribute::SupplementalAttribute)
    container = get_time_series_container(attribute)
    if isnothing(container)
        return nothing
    end

    return container.time_series_storage
end

function clear_time_series!(
    attribute::T,
) where {T <: SupplementalAttribute}
    container = get_time_series_container(attribute)
    if !isnothing(container)
        clear_time_series!(container)
        @debug "Cleared time_series in attribute type $T, $(get_uuid(attribute))." _group =
            LOG_GROUP_TIME_SERIES
    end
    return
end
