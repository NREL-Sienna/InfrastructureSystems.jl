
const ComponentsByType = Dict{DataType, Dict{String, <:InfrastructureSystemsComponent}}

struct Components
    data::ComponentsByType
    time_series_storage::TimeSeriesStorage
    validation_descriptors::Vector
end

function Components(
    time_series_storage::TimeSeriesStorage,
    validation_descriptors = nothing,
)
    if isnothing(validation_descriptors)
        validation_descriptors = Vector()
    end

    return Components(ComponentsByType(), time_series_storage, validation_descriptors)
end

function serialize(components::Components)
    # time_series_storage and validation_descriptors are serialized elsewhere.
    return [serialize(x) for y in values(components.data) for x in values(y)]
end

function _add_component!(
    components::Components,
    component::T;
    skip_validation = false,
    allow_existing_time_series = false,
) where {T <: InfrastructureSystemsComponent}
    component_name = get_name(component)
    if !isconcretetype(T)
        throw(ArgumentError("add_component! only accepts concrete types"))
    end

    if !haskey(components.data, T)
        components.data[T] = Dict{String, T}()
    elseif haskey(components.data[T], component_name)
        throw(ArgumentError("$(component_name) is already stored for type $T"))
    end

    !skip_validation && check_component(components, component)

    if !allow_existing_time_series && has_time_series(component)
        throw(ArgumentError("cannot add a component with time_series: $component"))
    end

    set_time_series_storage!(component, components.time_series_storage)
    components.data[T][component_name] = component
    return
end

"""
Add a component.

Throws ArgumentError if the component's name is already stored for its concrete type.

Throws InvalidRange if any of the component's field values are outside of defined valid
range.
"""
function add_component!(
    components::Components,
    component::T;
    kwargs...,
) where {T <: InfrastructureSystemsComponent}
    kw = _add_component_kwarg_deprecation(kwargs)
    _add_component!(components, component; kw...)
    return
end

function check_components(components::Components)
    for component in iterate_components(components)
        check_component(component)
    end
end

function check_component(components::Components, comp::InfrastructureSystemsComponent)
    if !isempty(components.validation_descriptors) && !validate_fields(components, comp)
        throw(InvalidRange("Invalid value"))
    end

    if !validate_struct(comp)
        throw(InvalidValue("Invalid value for $(comp)"))
    end
end

"""
Removes all components from the system.
"""
function clear_components!(components::Components)
    for type_ in collect(keys(components.data))
        remove_components!(type_, components)
    end
end

"""
Remove all components of type T.

Throws ArgumentError if the type is not stored.
"""
function remove_components!(
    ::Type{T},
    components::Components,
) where {T <: InfrastructureSystemsComponent}
    if !haskey(components.data, T)
        throw(ArgumentError("component $T is not stored"))
    end

    _components = pop!(components.data, T)
    for component in values(_components)
        prepare_for_removal!(component)
    end

    @debug "Removed all components of type" _group = LOG_GROUP_SYSTEM T
    return values(_components)
end

"""
Remove a component by its value.

Throws ArgumentError if the component is not stored.
"""
function remove_component!(
    components::Components,
    component::T;
    remove_time_series = true,
) where {T <: InfrastructureSystemsComponent}
    return _remove_component!(
        T,
        components,
        get_name(component),
        remove_time_series = remove_time_series,
    )
end

"""
Remove a component by its name.

Throws ArgumentError if the component is not stored.
"""
function remove_component!(
    ::Type{T},
    components::Components,
    name::AbstractString;
    remove_time_series = true,
) where {T <: InfrastructureSystemsComponent}
    return _remove_component!(T, components, name, remove_time_series = remove_time_series)
end

function _remove_component!(
    ::Type{T},
    components::Components,
    name::AbstractString;
    remove_time_series = true,
) where {T <: InfrastructureSystemsComponent}
    if !haskey(components.data, T)
        throw(ArgumentError("component $T is not stored"))
    end

    if !haskey(components.data[T], name)
        throw(ArgumentError("component $T name=$name is not stored"))
    end

    component = pop!(components.data[T], name)
    if isempty(components.data[T])
        pop!(components.data, T)
    end

    if remove_time_series
        prepare_for_removal!(component)
    end

    @debug "Removed component" _group = LOG_GROUP_SYSTEM T name
    return component
end

"""
Check to see if a component exists.
"""
function has_component(
    ::Type{T},
    components::Components,
    name::AbstractString,
) where {T <: InfrastructureSystemsComponent}
    !isconcretetype(T) && return !isempty(get_components_by_name(T, components, name))
    !haskey(components.data, T) && return false
    return haskey(components.data[T], name)
end

"""
Get the component of type T with name. Returns nothing if no component matches. If T is an abstract
type then the names of components across all subtypes of T must be unique.

See [`get_components_by_name`](@ref) for abstract types with non-unique names across subtypes.

Throws ArgumentError if T is not a concrete type and there is more than one component with
    requested name
"""
function get_component(
    ::Type{T},
    components::Components,
    name::AbstractString,
)::Union{T, Nothing} where {T <: InfrastructureSystemsComponent}
    if !isconcretetype(T)
        components = get_components_by_name(T, components, name)
        if length(components) > 1
            throw(
                ArgumentError(
                    "More than one abstract component of type $T with name $name in the system. Operation can't continue",
                ),
            )
        end
        return isempty(components) ? nothing : first(components)
    end

    if !haskey(components.data, T)
        @debug "components of type $T are not stored" _group = LOG_GROUP_SYSTEM
        return nothing
    end

    return get(components.data[T], name, nothing)
end

"""
Get the components of abstract type T with name. Note that
InfrastructureSystems enforces unique names on each concrete type but not
across concrete types.

See [`get_component`](@ref) if the concrete type is known.

Throws ArgumentError if T is not an abstract type.
"""
function get_components_by_name(
    ::Type{T},
    components::Components,
    name::AbstractString,
) where {T <: InfrastructureSystemsComponent}
    if isconcretetype(T)
        throw(ArgumentError("get_components_by_name does not support concrete types: $T"))
    end

    _components = Vector{T}()
    for key in keys(components.data)
        if key <: T
            component = get_component(key, components, name)
            if !isnothing(component)
                push!(_components, component)
            end
        end
    end

    return _components
end

"""
Returns an iterator of components. T can be concrete or abstract.
Call collect on the result if an array is desired.

# Arguments
- `T`: component type
- `components::Components`: Components of the sytem
- `filter_func::Union{Nothing, Function} = nothing`: Optional function that accepts a component
   of type T and returns a Bool. Apply this function to each component and only return components
   where the result is true.

See also: [`iterate_components`](@ref)
"""
function get_components(
    ::Type{T},
    components::Components,
    filter_func::Union{Nothing, Function} = nothing,
) where {T <: InfrastructureSystemsComponent}
    if isconcretetype(T)
        _components = get(components.data, T, nothing)
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
        types = [x for x in keys(components.data) if x <: T]
        if isnothing(filter_func)
            _components = [values(components.data[x]) for x in types]
        else
            _filter_func = x -> filter_func(x.second)
            _components = [values(filter(_filter_func, components.data[x])) for x in types]
        end
        iter = FlattenIteratorWrapper(T, _components)
    end

    @assert_op eltype(iter) == T
    return iter
end

"""
Iterates over all components.

# Examples
```Julia
for component in iterate_components(obj)
    @show component
end
```

See also: [`get_components`](@ref)
"""
function iterate_components(components::Components)
    Channel() do channel
        for comp_dict in values(components.data)
            for component in values(comp_dict)
                put!(channel, component)
            end
        end
    end
end

function iterate_components_with_time_series(components::Components)
    Channel() do channel
        for comp_dict in values(components.data)
            for component in values(comp_dict)
                if has_time_series(component)
                    put!(channel, component)
                end
            end
        end
    end
end

function get_num_components(components::Components)
    count = 0
    for components in values(components.data)
        count += length(components)
    end
    return count
end

function clear_time_series!(components::Components)
    for component in iterate_components_with_time_series(components)
        clear_time_series!(component)
    end
end

function is_attached(
    component::T,
    components::Components,
) where {T <: InfrastructureSystemsComponent}
    !in(T, keys(components.data)) && return false
    return get_name(component) in keys(components.data[T])
end

function set_name!(
    components::Components,
    component::T,
    name,
) where {T <: InfrastructureSystemsComponent}
    if !is_attached(component, components)
        throw(ArgumentError("$(summary(component)) is not attached to the system"))
    end

    old_name = get_name(component)
    _component = components.data[T][old_name]

    if component !== _component
        throw(
            ArgumentError(
                "component does not match the stored component: $(summary(component))",
            ),
        )
    end

    pop!(components.data[T], old_name)
    set_name!(component, name)
    components.data[T][name] = component
    @debug "Changed the name of component $(summary(component))" _group LOG_GROUP_SYSTEM
end
