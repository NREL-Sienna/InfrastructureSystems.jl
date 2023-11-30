const InfosContainer = Dict{DataType, Set{<:InfrastructureSystemsInfo}}
const InfosByType = Dict{DataType, Dict{UUIDs.UUID, <:InfrastructureSystemsInfo}}

struct Infos <: InfrastructureSystemsContainer
    data::InfosByType
    time_series_storage::TimeSeriesStorage
end

get_display_string(::Infos) = "Infos"

function Infos(time_series_storage::TimeSeriesStorage)
    return Infos(InfosByType(), time_series_storage)
end

function add_info!(
    infos::Infos,
    component::InfrastructureSystemsComponent,
    info::InfrastructureSystemsInfo;
    kwargs...
)
    attach_info!(component, info)
    _add_info!(infos, info; kwargs...)
    return
end

function _add_info!(
    infos::Infos,
    info::T;
    allow_existing_time_series=false,
) where {T <: InfrastructureSystemsInfo}
    if !isconcretetype(T)
        throw(ArgumentError("add_info! only accepts concrete types"))
    end

    info_uuid = get_uuid(info)
    if isempty(get_components_uuid(info))
        throw(
            ArgumentError(
                "Info type $T with UUID $info_uuid is not attached to any component",
            ),
        )
    end

    if !haskey(infos.data, T)
        infos.data[T] = Dict{UUIDs.UUID, T}()
    elseif haskey(infos.data[T], info_uuid)
        @debug "Info type $T with UUID $info_uuid already stored"
        return
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
    component::U,
) where {T <: InfrastructureSystemsInfo, U <: InfrastructureSystemsComponent}
    if !isconcretetype(T)
        infos = [v for v in values(get_infos_container(component)) if !isempty(v)]
        return !isempty(infos)
    end
    infos = get_infos_container(component)
    !haskey(infos, T) && return false
    return !isempty(infos[T])
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

"""
Removes all infos from the system.
"""
function clear_infos!(infos::Infos)
    for type_ in collect(keys(infos.data))
        remove_infos!(type_, infos)
    end
end

function remove_info!(infos::Infos, info::T) where {T <: InfrastructureSystemsInfo}
    if !isempty(get_components_uuid(info))
        throw(
            ArgumentError(
                "Info type $T with uuid $(get_uuid(info)) still attached to devices $(get_components_uuid(info))",
            ),
        )
    end

    pop!(infos.data[T], get_uuid(info))
    return
end

"""
Remove all infos of type T.

Throws ArgumentError if the type is not stored.
"""
function remove_infos!(::Type{T}, infos::Infos) where {T <: InfrastructureSystemsInfo}
    if !haskey(infos.data, T)
        throw(ArgumentError("info type $T is not stored"))
    end

    _infos = pop!(infos.data, T)
    for info in values(_infos)
        prepare_for_removal!(info)
    end

    @debug "Removed all infos of type $T" _group = LOG_GROUP_SYSTEM T
    return values(_infos)
end

"""
Returns an iterator of infos. T can be concrete or abstract.
Call collect on the result if an array is desired.

# Arguments

  - `T`: info type
  - `infos::Infos`: Infos in the system
  - `filter_func::Union{Nothing, Function} = nothing`: Optional function that accepts a component
    of type T and returns a Bool. Apply this function to each component and only return components
    where the result is true.
"""
function get_infos(
    ::Type{T},
    infos::Infos,
    filter_func::Union{Nothing, Function}=nothing,
) where {T <: InfrastructureSystemsInfo}
    if isconcretetype(T)
        _infos = get(infos.data, T, nothing)
        if !isnothing(filter_func) && !isnothing(_infos)
            _filter_func = x -> filter_func(x.second)
            _infos = values(filter(_filter_func, _infos))
        end
        if isnothing(_infos)
            iter = FlattenIteratorWrapper(T, Vector{Base.ValueIterator}([]))
        else
            iter = FlattenIteratorWrapper(T, Vector{Base.ValueIterator}([values(_infos)]))
        end
    else
        types = [x for x in keys(infos.data) if x <: T]
        if isnothing(filter_func)
            _infos = [values(infos.data[x]) for x in types]
        else
            _filter_func = x -> filter_func(x.second)
            _infos = [values(filter(_filter_func, infos.data[x])) for x in types]
        end
        iter = FlattenIteratorWrapper(T, _infos)
    end

    @assert_op eltype(iter) == T
    return iter
end
