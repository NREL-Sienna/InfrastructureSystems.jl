
const ComponentsByType = Dict{DataType, Dict{String, <:InfrastructureSystemsType}}

struct Components
    data::ComponentsByType
    validation_descriptors::Vector
end

function Components(validation_descriptors=nothing)
    if isnothing(validation_descriptors)
        validation_descriptors = Vector()
    end

    return Components(ComponentsByType(), validation_descriptors)
end

"""
    add_component!(
                   components::Components,
                   component::T;
                   kwargs...
                  ) where T <: InfrastructureSystemsType

Add a component.

Throws ArgumentError if the component's name is already stored for its concrete type.

Throws InvalidRange if any of the component's field values are outside of defined valid
range.
"""
function add_component!(
                        components::Components,
                        component::T;
                        skip_validation=false,
                       ) where T <: InfrastructureSystemsType
    if !isconcretetype(T)
        throw(ArgumentError("add_component! only accepts concrete types"))
    end

    if !haskey(components.data, T)
        components.data[T] = Dict{String, T}()
    elseif haskey(components.data[T], component.name)
        throw(ArgumentError("$(component.name) is already stored for type $T"))
    end

    if !isempty(components.validation_descriptors) && !skip_validation
        if !validate_fields(components, component)
            throw(InvalidRange("Invalid value"))
        end
    end

    if !skip_validation && !validate_struct(component)
        throw(InvalidValue("Invalid value for $(component)"))
    end

    components.data[T][component.name] = component
    return
end

"""
    remove_components!(
                       ::Type{T},
                       components::Components,
                      ) where T <: InfrastructureSystemsType

Remove all components of type T.

Throws ArgumentError if the type is not stored.
"""
function remove_components!(
                            ::Type{T},
                            components::Components,
                           ) where T <: InfrastructureSystemsType
    if !haskey(components.data, T)
        throw(ArgumentError("component $T is not stored"))
    end

    pop!(components.data, T)
    @debug "Removed all components of type" T
end

"""
    remove_component!(
                      components::Components,
                      component::T,
                     ) where T <: InfrastructureSystemsType

Remove a component by its value.

Throws ArgumentError if the component is not stored.
"""
function remove_component!(
                           components::Components,
                           component::T,
                          ) where T <: InfrastructureSystemsType
    _remove_component!(T, components, get_name(component))
end

"""
    remove_component!(
                      ::Type{T},
                      components::Components,
                      name::AbstractString,
                      ) where T <: InfrastructureSystemsType

Remove a component by its name.

Throws ArgumentError if the component is not stored.
"""
function remove_component!(
                           ::Type{T},
                           components::Components,
                           name::AbstractString,
                          ) where T <: InfrastructureSystemsType
    _remove_component!(T, components, name)
end

function _remove_component!(
                            ::Type{T},
                            components::Components,
                            name::AbstractString,
                           ) where T <: InfrastructureSystemsType
    if !haskey(components.data, T)
        throw(ArgumentError("component $T is not stored"))
    end

    if !haskey(components.data[T], name)
        throw(ArgumentError("component $T name=$name is not stored"))
    end

    pop!(components.data[T], name)
    @debug "Removed component" T name
end

"""
    get_component(
                  ::Type{T},
                  components::Components,
                  name::AbstractString
                 )::Union{T, Nothing} where T <: InfrastructureSystemsType

Get the component of concrete type T with name. Returns nothing if no component matches.

See [`get_components_by_name`](@ref) if the concrete type is unknown.

Throws ArgumentError if T is not a concrete type.
"""
function get_component(
                       ::Type{T},
                       components::Components,
                       name::AbstractString
                      )::Union{T, Nothing} where T <: InfrastructureSystemsType
    if !isconcretetype(T)
        throw(ArgumentError("get_component only supports concrete types: $T"))
    end

    if !haskey(components.data, T)
        @debug "components of type $T are not stored"
        return nothing
    end

    return get(components.data[T], name, nothing)
end

"""
    get_components_by_name(
                           ::Type{T},
                           components::Components,
                           name::AbstractString
                          )::Vector{T} where T <: InfrastructureSystemsType

Get the components of abstract type T with name. Note that
InfrastructureSystems enforces unique names on each concrete type but not
across concrete types.

See [`get_component`](@ref) if the concrete type is known.

Throws ArgumentError if T is not an abstract type.
"""
function get_components_by_name(
                                ::Type{T},
                                components::Components,
                                name::AbstractString
                               )::Vector{T} where T <: InfrastructureSystemsType
    if !isabstracttype(T)
        throw(ArgumentError("get_components_by_name only supports abstract types: $T"))
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
                  )::FlattenIteratorWrapper{T} where T <: InfrastructureSystemsType

Returns an iterator of components. T can be concrete or abstract.
Call collect on the result if an array is desired.

See also: [`iterate_components`](@ref)
"""
function get_components(
                        ::Type{T},
                        components::Components,
                       )::FlattenIteratorWrapper{T} where T <: InfrastructureSystemsType
    if isconcretetype(T)
        components_ = get(components.data, T, nothing)
        if isnothing(components_)
            iter = FlattenIteratorWrapper(T, Vector{Base.ValueIterator}([]))
        else
            iter = FlattenIteratorWrapper(T,
                                          Vector{Base.ValueIterator}([values(components_)]))
        end
    else
        types = [x for x in get_all_concrete_subtypes(T) if haskey(components.data, x)]
        iter = FlattenIteratorWrapper(T, [values(components.data[x]) for x in types])
    end

    @assert eltype(iter) == T
    return iter
end

"""
    iterate_components(obj) where T <: InfrastructureSystemsType

Iterates over all components.

# Examples
```julia
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

function JSON2.write(io::IO, components::Components)
    return JSON2.write(io, encode_for_json(components))
end

function JSON2.write(components::Components)
    return JSON2.write(encode_for_json(components))
end

function encode_for_json(components::Components)
    # Convert each name-to-value component dictionary to arrays.
    new_components = Dict{DataType, Vector{<:InfrastructureSystemsType}}()
    for (data_type, component_dict) in components.data
        new_components[data_type] = [x for x in values(component_dict)]
    end

    return new_components
end

"""
Return an iterable of component types deserialized from JSON.
"""
function get_component_types_raw(::Type{Components}, raw::NamedTuple)
    return propertynames(raw)
end

"""
Return an iterable of components as NamedTuples deserialized from JSON.
"""
function get_components_raw(
                            ::Type{Components},
                            ::Type{T},
                            raw::NamedTuple,
                           ) where T <: InfrastructureSystemsType
    return getproperty(raw, Symbol(T))  
end

function JSON2.read(io::IO, ::Type{Components})
    raw = JSON2.read(io, NamedTuple)
    parent_module = getfield(Main, Symbol(raw.parent_module))
end
