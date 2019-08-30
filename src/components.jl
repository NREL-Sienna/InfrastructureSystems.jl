
const _ComponentsContainer = Dict{DataType, Dict{String, <:T}} where T <: InfrastructureSystemType

struct Components{T}
    _store::_ComponentsContainer
end

function Components{T}() where T <: InfrastructureSystemType
    return Components{T}(_ComponentsContainer{T}())
end

"""
    add_component!(components::Components, component::T) where T <: InfrastructureSystemType

Add a component to the system.

Throws InvalidParameter if the component's name is already stored for its concrete type.

Throws InvalidRange if any of the component's field values are outside of defined valid range.
"""
function add_component!(components::Components, component::T) where T <: InfrastructureSystemType
    if !isconcretetype(T)
        error("add_component! only accepts concrete types")
    end

    if !haskey(components._store, T)
        components._store[T] = Dict{String, T}()
    elseif haskey(components._store[T], component.name)
        throw(InvalidParameter("$(component.name) is already stored for type $T"))
    end

    components._store[T][component.name] = component
end

"""
    remove_components!(::Type{T}, components::Components) where T <: InfrastructureSystemType

Remove all components of type T from the system.

Throws InvalidParameter if the type is not stored.
"""
function remove_components!(::Type{T}, components::Components) where T <: InfrastructureSystemType
    if !haskey(components._store, T)
        throw(InvalidParameter("component $T is not stored"))
    end

    pop!(components._store, T)
    @debug "Removed all components of type" T
end

"""
    remove_component!(components::Components, component::T) where T <: InfrastructureSystemType

Remove a component from the system by its value.

Throws InvalidParameter if the component is not stored.
"""
function remove_component!(components::Components, component::T) where T <: InfrastructureSystemType
    _remove_component!(T, components, get_name(component))
end

"""
    remove_component!(
                      ::Type{T},
                      components::Components,
                      name::AbstractString,
                      ) where T <: InfrastructureSystemType

Remove a component from the system by its name.

Throws InvalidParameter if the component is not stored.
"""
function remove_component!(
                           ::Type{T},
                           components::Components,
                           name::AbstractString,
                          ) where T <: InfrastructureSystemType
    _remove_component!(T, components, name)
end

function _remove_component!(
                            ::Type{T},
                            components::Components,
                            name::AbstractString,
                           ) where T <: InfrastructureSystemType
    if !haskey(components._store, T)
        throw(InvalidParameter("component $T is not stored"))
    end

    if !haskey(components._store[T], name)
        throw(InvalidParameter("component $T name=$name is not stored"))
    end

    pop!(components._store[T], name)
    @debug "Removed component" T name
end

"""
    get_component(
                  ::Type{T},
                  components::Components,
                  name::AbstractString
                 )::Union{T, Nothing} where T <: InfrastructureSystemType

Get the component of concrete type T with name. Returns nothing if no component matches.

See [`get_components_by_name`](@ref) if the concrete type is unknown.

Throws InvalidParameter if T is not a concrete type.
"""
function get_component(
                       ::Type{T},
                       components::Components,
                       name::AbstractString
                      )::Union{T, Nothing} where T <: InfrastructureSystemType
    if !isconcretetype(T)
        throw(InvalidParameter("get_component only supports concrete types: $T"))
    end

    if !haskey(components._store, T)
        @debug "components of type $T are not stored"
        return nothing
    end

    return get(components._store[T], name, nothing)
end

"""
    get_components_by_name(
                           ::Type{T},
                           components::Components,
                           name::AbstractString
                          )::Vector{T} where T <: InfrastructureSystemType

Get the components of abstract type T with name. Note that
InfrastructureSystems enforces unique names on each concrete type but not
across concrete types.

See [`get_component`](@ref) if the concrete type is known.

Throws InvalidParameter if T is not an abstract type.
"""
function get_components_by_name(
                                ::Type{T},
                                components::Components,
                                name::AbstractString
                               )::Vector{T} where T <: InfrastructureSystemType
    if !isabstracttype(T)
        throw(InvalidParameter("get_components_by_name only supports abstract types: $T"))
    end

    components_ = Vector{T}()
    for subtype in get_all_concrete_subtypes(T)
        component = get_component(subtype, components, name)
        if !isnothing(component)
            push!(components_, component)
        end
    end

    return components_
end

"""
    get_components(
                   ::Type{T},
                   components::Components,
                  )::FlattenIteratorWrapper{T} where T <: InfrastructureSystemType

Returns an iterator of components. T can be concrete or abstract.
Call collect on the result if an array is desired.

# Examples
```julia
iter = InfrastructureSystems.get_components(ThermalStandard, sys)
iter = InfrastructureSystems.get_components(Generator, sys)
components = InfrastructureSystems.get_components(Generator, sys) |> collect
components = collect(InfrastructureSystems.get_components(Generator, sys))
```

See also: [`iterate_components`](@ref)
"""
function get_components(
                        ::Type{T},
                        components::Components,
                       )::FlattenIteratorWrapper{T} where T <: InfrastructureSystemType
    if isconcretetype(T)
        components_ = get(components._store, T, nothing)
        if isnothing(components_)
            iter = FlattenIteratorWrapper(T, Vector{Base.ValueIterator}([]))
        else
            iter = FlattenIteratorWrapper(T,
                                          Vector{Base.ValueIterator}([values(components_)]))
        end
    else
        types = [x for x in get_all_concrete_subtypes(T) if haskey(components._store, x)]
        iter = FlattenIteratorWrapper(T, [values(components._store[x]) for x in types])
    end

    @assert eltype(iter) == T
    return iter
end

"""Iterates over all components.

# Examples
```julia
for component in iterate_components(sys)
    @show component
end
```

See also: [`get_components`](@ref)
"""
function iterate_components(components::Components{T}) where T <: InfrastructureSystemType
    Channel() do channel
        for component in get_components(T, components)
            put!(channel, component)
        end
    end
end

function Base.summary(io::IO, components::Components)
    counts = Dict{String, Int}()
    rows = []

    for (subtype, values) in components._store
        type_str = strip_module_names(string(subtype))
        counts[type_str] = length(values)
        parents = [strip_module_names(string(x)) for x in supertypes(subtype)]
        row = (ConcreteType=type_str,
               SuperTypes=join(parents, " <: "),
               Count=length(values))
        push!(rows, row)
    end

    sort!(rows, by = x -> x.ConcreteType)

    df = DataFrames.DataFrame(rows)
    println(io, "Components")
    println(io, "==========")
    Base.show(io, df)
end

