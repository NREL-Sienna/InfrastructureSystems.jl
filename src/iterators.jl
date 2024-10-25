const _ContainerTypes = Union{ComponentsByType, SupplementalAttributesByType}

function iterate_instances(
    filter_func::Function,
    ::Type{T},
    data::_ContainerTypes,
    uuids::Set{Base.UUID},
) where {T <: InfrastructureSystemsType}
    func_uuids = x -> get_uuid(x) in uuids
    _filter_func = x -> filter_func(x) && func_uuids(x)
    return iterate_instances(_filter_func, T, data, nothing)
end

function iterate_instances(
    ::Type{T},
    data::_ContainerTypes,
    uuids::Set{Base.UUID},
) where {T <: InfrastructureSystemsType}
    filter_func = x -> get_uuid(x) in uuids
    return iterate_instances(filter_func, T, data, nothing)
end

function iterate_instances(
    ::Type{T},
    data::_ContainerTypes,
    ::Nothing,
) where {T <: InfrastructureSystemsType}
    if isconcretetype(T)
        instances = get(data, T, nothing)
        iter = if isnothing(instances)
            _make_empty_iterator(T)
        else
            _make_iterator_from_concrete_dict(T, instances)
        end
    else
        types = _get_concrete_types(T, data)
        iter = FlattenIteratorWrapper(T, [values(data[x]) for x in types])
    end

    @assert_op eltype(iter) == T
    return iter
end

function iterate_instances(
    filter_func::Function,
    ::Type{T},
    data::_ContainerTypes,
    ::Nothing,
) where {T <: InfrastructureSystemsType}
    if isconcretetype(T)
        instances = get(data, T, nothing)
        if isnothing(instances)
            iter = _make_empty_iterator(T)
        else
            _filter_func = x -> filter_func(x.second)
            filtered_instances = filter(_filter_func, instances)
            iter = _make_iterator_from_concrete_dict(T, filtered_instances)
        end
    else
        types = _get_concrete_types(T, data)
        _filter_func = x -> filter_func(x.second)
        filtered_instances = [values(filter(_filter_func, data[x])) for x in types]
        iter = FlattenIteratorWrapper(T, filtered_instances)
    end

    @assert_op eltype(iter) == T
    return iter
end

function _make_iterator_from_concrete_dict(
    ::Type{T},
    instances::Dict,
) where {T <: InfrastructureSystemsType}
    return FlattenIteratorWrapper(T, Vector{Base.ValueIterator}([values(instances)]))
end

function _make_empty_iterator(::Type{T}) where {T <: InfrastructureSystemsType}
    return FlattenIteratorWrapper(T, Vector{Base.ValueIterator}([]))
end

function _get_concrete_types(
    ::Type{T},
    data::_ContainerTypes,
) where {T <: InfrastructureSystemsType}
    return [x for x in keys(data) if x <: T]
end

function Base.filter(filter_func::Function, iter::FlattenIteratorWrapper{T, I}) where {T, I}
    # PERF note that here we materialize everything
    filtered_items = filter(filter_func, collect(iter))
    # NOTE that we don't currently require the second type parameter of `result` to be `I`.
    # This is because `I` is often something like `Vector{Base.ValueIterator}` that it
    # doesn't make sense to reconstruct. We do, however, guarantee that the first type
    # parameter of `result` is `T` and that this method is type stable given `T` and `I`.
    return FlattenIteratorWrapper(T, [filtered_items])
end
