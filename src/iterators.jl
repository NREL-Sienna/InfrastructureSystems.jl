function iterate_instances(
    ::Type{T},
    data::Union{ComponentsByType, SupplementalAttributesByType},
    filter_func::Union{Nothing, Function} = nothing,
) where {T <: InfrastructureSystemsType}
    if isconcretetype(T)
        _components = get(data, T, nothing)
        if !isnothing(filter_func) && !isnothing(_components)
            _filter_func = x -> filter_func(x.second)
            _components = values(filter(_filter_func, _components))
        end
        if isnothing(_components)
            iter = FlattenIteratorWrapper(T, Vector{Base.ValueIterator}([]))
        else
            iter =
                FlattenIteratorWrapper(T, Vector{Base.ValueIterator}([values(_components)]))
        end
    else
        types = [x for x in keys(data) if x <: T]
        if isnothing(filter_func)
            _components = [values(data[x]) for x in types]
        else
            _filter_func = x -> filter_func(x.second)
            _components = [values(filter(_filter_func, data[x])) for x in types]
        end
        iter = FlattenIteratorWrapper(T, _components)
    end

    @assert_op eltype(iter) == T
    return iter
end
