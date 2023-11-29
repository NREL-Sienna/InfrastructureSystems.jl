const InfosContainer = Dict{DataType, Set{<:InfrastructureSystemsInfo}}
const InfosByType = Dict{DataType, Dict{UUIDs.UUID, <:InfrastructureSystemsInfo}}

struct Infos <: InfrastructureSystemsContainer
    data::InfosByType
    time_series_storage::TimeSeriesStorage
end

function Infos(time_series_storage::TimeSeriesStorage)
    return Infos(InfosByType(), time_series_storage)
end

function add_info!(
    infos::Infos,
    info::T,
    component::U;
    kwargs...,
) where {T <: InfrastructureSystemsInfo, U <: InfrastructureSystemsComponent}
    attach_info!(component, info)
    add_info!(infos, info; kwargs...)
    return
end

function add_info!(
    infos::Infos,
    info::T;
    allow_existing_time_series=false,
) where {T <: InfrastructureSystemsInfo}
    if !isconcretetype(T)
        throw(ArgumentError("add_info! only accepts concrete types"))
    end

    if !haskey(infos.data, T)
        components.data[T] = Dict{UUIDs.UUID, T}()
    elseif haskey(components.data[T], get_uuid(info))
        throw(ArgumentError("Info type $T with UUID $(get_uuid(info)) already stored"))
    end

    if !allow_existing_time_series && has_time_series(info)
        throw(ArgumentError("cannot add an info with time_series: $info"))
    end

    set_time_series_storage!(info, infos.time_series_storage)
    infos.data[T][component_uuid] = info
    return
end

"""
Check to see if info exists.
"""
function has_info(
    ::Type{T},
    infos::Infos,
    component::U,
) where {T <: InfrastructureSystemsComponent, U <: InfrastructureSystemsComponent}
    !isconcretetype(T) && return !isempty(get_components_by_name(T, components, name))
    !haskey(components.data, T) && return false
    return haskey(components.data[T], name)
end
