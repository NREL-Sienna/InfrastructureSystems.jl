"""
Return true if the info has time series data.
"""
function has_time_series(info::InfrastructureSystemsSupplementalAttribute)
    container = get_time_series_container(info)
    return !isnothing(container) && !isempty(container)
end

function clear_time_series_storage!(info::InfrastructureSystemsSupplementalAttribute)
    storage = _get_time_series_storage(info)
    if !isnothing(storage)
        # In the case of Deterministic and DeterministicSingleTimeSeries the UUIDs
        # can be shared.
        uuids = Set{Base.UUID}()
        for (uuid, name) in get_time_series_uuids(info)
            if !(uuid in uuids)
                remove_time_series!(storage, uuid, get_uuid(info), name)
                push!(uuids, uuid)
            end
        end
    end
end

function set_time_series_storage!(
    info::InfrastructureSystemsSupplementalAttribute,
    storage::Union{Nothing, TimeSeriesStorage},
)
    container = get_time_series_container(info)
    if !isnothing(container)
        set_time_series_storage!(container, storage)
    end
    return
end

"""
This function must be called when an attribute is removed from a system.
"""
function prepare_for_removal!(
    info::T,
) where {T <: InfrastructureSystemsSupplementalAttribute}
    if !isempty(get_components_uuids(info))
        throw(
            ArgumentError(
                "info type $T with uuid $(get_uuid(info)) still attached to a component",
            ),
        )
    end

    # TimeSeriesContainer can only be part of a component when that component is part of a
    # system.
    clear_time_series_storage!(info)
    set_time_series_storage!(info, nothing)
    clear_time_series!(info)
    @debug "cleared all time series data from" _group = LOG_GROUP_SYSTEM get_uuid(attribute)
    return
end

function _get_time_series_storage(info::InfrastructureSystemsSupplementalAttribute)
    container = get_time_series_container(info)
    if isnothing(container)
        return nothing
    end

    return container.time_series_storage
end

function clear_time_series!(info::T) where {T <: InfrastructureSystemsSupplementalAttribute}
    container = get_time_series_container(info)
    if !isnothing(container)
        clear_time_series!(container)
        @debug "Cleared time_series in info type $T, $(get_uuid(info))." _group =
            LOG_GROUP_TIME_SERIES
    end
    return
end
