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

    info_uuid = get_uuid(info)
    if !haskey(infos.data, T)
        infos.data[T] = Dict{UUIDs.UUID, T}()
    elseif haskey(infos.data[T], info_uuid)
        throw(ArgumentError("Info type $T with UUID $info_uuid already stored"))
    end

    if !allow_existing_time_series && has_time_series(info)
        throw(ArgumentError("cannot add an info with time_series: $info"))
    end

    set_time_series_storage!(info, infos.time_series_storage)
    infos.data[T][info_uuid] = info
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

"""
Iterates over all infos.

# Examples

```Julia
for info in iterate_infos(obj)
    @show info
end
```
"""
function iterate_infos(infos::Infos)
    iterate_container(infos)
end

function iterate_infos_with_time_series(infos::Infos)
    iterate_container_with_time_series(infos)
end

"""
Returns the total number of stored infos
"""
function get_num_infos(infos::Infos)
    return get_num_members(infos)
end
