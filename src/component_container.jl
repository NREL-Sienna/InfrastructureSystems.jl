"A data structure that acts like a container of components"
abstract type ComponentContainer <: InfrastructureSystemsContainer end

# For each of these functions, `ComponentContainer` concrete subtypes MUST either implement
# appropriate methods or accept the default if it exists.
#   - `get_components`: no default, must at least implement the `(type, system)` and `(filter_func, type, system)` signatures.
#   - `get_component`: no default, must at least implement the `(type, system, name)` signature, may also want `(system, UUID)`, etc.
#   - `get_available(::ComponentContainer, ::InfrastructureSystemsComponent)`: defaults to true
#   - `get_available_components`: defaults to calling `get_components` with a filter function from `get_available`
#   - `get_available_component`: defaults to calling `get_component` and checking `get_available`
# The notion of availability used in `get_available` and `get_available_component(s)` is up
# to the subtype, but it must be consistent across the three functions.

"Get an iterator of components of a certain specification from the `ComponentContainer`."
function get_components end

"Get the single component that matches the given specification from the `ComponentContainer`, or `nothing` if there is no match."
function get_component end

"Get whether the given component of the given system is available for use (defaults to true)."
get_available(::ComponentContainer, ::InfrastructureSystemsComponent) = true

"Like `get_components` but only on components that are available."
function get_available_components end

"Like `get_component` but only on components that are available."
function get_available_component end

get_available_components(sys::ComponentContainer, args...; kwargs...) =
    get_components(c -> get_available(sys, c), sys, args...; kwargs...)

get_available_components(
    ::Type{T},
    sys::ComponentContainer,
    args...;
    kwargs...,
) where {T <: InfrastructureSystemsComponent} =
    get_components(c -> get_available(sys, c), T, sys, args...; kwargs...)

get_available_components(
    filter_func::Function,
    ::Type{T},
    sys::ComponentContainer,
    args...;
    kwargs...,
) where {T <: InfrastructureSystemsComponent} =
    get_components(x -> get_available(sys, x) && filter_func(x), T, sys, args...; kwargs...)

# Helper function to most generically implement get_available_component
function _get_available_component(sys::ComponentContainer, args...; kwargs...)
    the_component = get_component(args...; kwargs...)
    return get_available(sys, the_component) ? the_component : nothing
end

get_available_component(
    ::Type{T},
    sys::ComponentContainer,
    name::AbstractString;
    kwargs...,
) where {T <: InfrastructureSystemsComponent} =
    _get_available_component(sys, T, sys, name; kwargs...)

get_available_component(sys::ComponentContainer, args...; kwargs...) =
    _get_available_component(sys, sys, args...; kwargs...)

# Satisfy the InfrastructureSystemsContainer interface
iterate_container(sys::ComponentContainer) =
    get_components(InfrastructureSystemsComponent, sys)

get_num_members(sys::ComponentContainer) =
    length(get_components(InfrastructureSystemsComponent, sys))
