# Store const definitions
# Update src/simulation/simulation_store_common.jl with any changes.
const STORE_CONTAINER_DUALS = :duals
const STORE_CONTAINER_PARAMETERS = :parameters
const STORE_CONTAINER_VARIABLES = :variables
const STORE_CONTAINER_AUX_VARIABLES = :aux_variables
const STORE_CONTAINER_EXPRESSIONS = :expressions
const STORE_CONTAINERS = (
    STORE_CONTAINER_DUALS,
    STORE_CONTAINER_PARAMETERS,
    STORE_CONTAINER_VARIABLES,
    STORE_CONTAINER_AUX_VARIABLES,
    STORE_CONTAINER_EXPRESSIONS,
)

# Keep these in sync with the Symbols in src/core/definitions.
get_store_container_type(::AuxVarKey) = STORE_CONTAINER_AUX_VARIABLES
get_store_container_type(::ConstraintKey) = STORE_CONTAINER_DUALS
get_store_container_type(::ExpressionKey) = STORE_CONTAINER_EXPRESSIONS
get_store_container_type(::ParameterKey) = STORE_CONTAINER_PARAMETERS
get_store_container_type(::VariableKey) = STORE_CONTAINER_VARIABLES

abstract type AbstractModelStore end

# Required fields for subtypes
# - :duals
# - :parameters
# - :variables
# - :aux_variables
# - :expressions

# Required methods for subtypes:
# - read_optimizer_stats
#
# Each subtype must have a field for each instance of STORE_CONTAINERS.

function Base.empty!(store::T) where {T <: AbstractModelStore}
    for (name, type) in zip(fieldnames(T), fieldtypes(T))
        val = get_data_field(store, name)
        try
            empty!(val)
        catch
            @error "Base.empty! must be customized for type $T or skipped"
            rethrow()
        end
    end
end

get_data_field(store::AbstractModelStore, type::Symbol) = getproperty(store, type)

function Base.isempty(store::T) where {T <: AbstractModelStore}
    for (name, type) in zip(fieldnames(T), fieldtypes(T))
        val = get_data_field(store, name)
        try
            !isempty(val) && return false
        catch
            @error "Base.isempty must be customized for type $T or skipped"
            rethrow()
        end
    end

    return true
end

function list_fields(store::AbstractModelStore, container_type::Symbol)
    return keys(get_data_field(store, container_type))
end

function list_keys(store::AbstractModelStore, container_type::Symbol)
    container = get_data_field(store, container_type)
    return collect(keys(container))
end

function get_value(
    store::AbstractModelStore,
    ::T,
    ::Type{U},
) where {T <: VariableType, U <: InfrastructureSystemsType}
    return get_data_field(store, STORE_CONTAINER_VARIABLES)[VariableKey(T, U)]
end

function get_value(
    store::AbstractModelStore,
    ::T,
    ::Type{U},
) where {T <: AuxVariableType, U <: InfrastructureSystemsType}
    return get_data_field(store, STORE_CONTAINER_AUX_VARIABLES)[AuxVarKey(T, U)]
end

function get_value(
    store::AbstractModelStore,
    ::T,
    ::Type{U},
) where {T <: ConstraintType, U <: InfrastructureSystemsType}
    return get_data_field(store, STORE_CONTAINER_DUALS)[ConstraintKey(T, U)]
end

function get_value(
    store::AbstractModelStore,
    ::T,
    ::Type{U},
) where {T <: ParameterType, U <: InfrastructureSystemsType}
    return get_data_field(store, STORE_CONTAINER_PARAMETERS)[ParameterKey(T, U)]
end

function get_value(
    store::AbstractModelStore,
    ::T,
    ::Type{U},
) where {T <: ExpressionType, U <: InfrastructureSystemsType}
    return get_data_field(store, STORE_CONTAINER_EXPRESSIONS)[ExpressionKey(T, U)]
end
