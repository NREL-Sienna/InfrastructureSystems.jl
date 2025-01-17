"""
To implement a sub-type of this you need to implement the methods below.
"""
abstract type Results end
function get_base_power(r::T) where {T <: Results}
    error("get_base_power must be implemented for $T")
end

function get_variables(r::T) where {T <: Results}
    error("get_variables must be implemented for $T")
end

function get_parameters(r::T) where {T <: Results}
    error("get_parameters must be implemented for $T")
end

function get_total_cost(r::T) where {T <: Results}
    error("get_total_cost must be implemented for $T")
end

function get_optimizer_stats(r::T) where {T <: Results}
    error("get_optimizer_stats must be implemented for $T")
end

function get_timestamp(r::T) where {T <: Results}
    error("get_timestamp must be implemented for $T")
end

function write_results(r::T) where {T <: Results}
    error("write_results must be implemented for $T")
end

# Must override if your concrete Results subtype has the notion of an associated source data
# (e.g., a system), otherwise can use the default
get_source_data(::Results) = nothing

# The below default implementations of `get_components`, `get_component`, `get_groups`
# should work fine for all `Results` subtypes if `get_source_data` returns either a
# `Nothing` or a `ComponentContainer`

_validate_components_source_data(::Nothing) =
    throw(ArgumentError("No system attached, need to call set_system!"))

# In all foreseeable cases this is a `ComponentContainer`; leaving it untyped for flexibility
_validate_components_source_data(data) = data  # Pass through on success

_get_components_source_data(res::Results) =
    _validate_components_source_data(get_source_data(res))

get_components(res::Results, args...; kwargs...) =
    get_available_components(_get_components_source_data(res), args...; kwargs...)

get_components(
    ::Type{T},
    res::Results,
    args...;
    kwargs...,
) where {T <: InfrastructureSystemsComponent} =
    get_available_components(T, _get_components_source_data(res), args...; kwargs...)

get_components(
    filter_func::Function,
    ::Type{T},
    res::Results,
    args...;
    kwargs...,
) where {T <: InfrastructureSystemsComponent} =
    get_available_components(filter_func, T,
        _get_components_source_data(res), args...; kwargs...)

get_component(
    ::Type{T},
    res::Results,
    name::AbstractString;
    kwargs...,
) where {T <: InfrastructureSystemsComponent} =
    get_available_component(T, _get_components_source_data(res), name; kwargs...)

get_component(res::Results, args...; kwargs...) =
    get_available_component(_get_components_source_data(res), args...; kwargs...)
