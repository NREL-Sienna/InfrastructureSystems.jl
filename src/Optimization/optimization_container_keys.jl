abstract type OptimizationContainerKey end

const _DELIMITER = "__"
const CONTAINER_KEY_EMPTY_META = ""

function make_key(::Type{T}, args...) where {T <: OptimizationContainerKey}
    return T(args...)
end

function encode_key(key::OptimizationContainerKey)
    return encode_symbol(get_component_type(key), get_entry_type(key), key.meta)
end

encode_key_as_string(key::OptimizationContainerKey) = string(encode_key(key))
encode_keys_as_strings(container_keys) = [encode_key_as_string(k) for k in container_keys]

function encode_symbol(
    ::Type{T},
    ::Type{U},
    meta::String = CONTAINER_KEY_EMPTY_META,
) where {T <: InfrastructureSystemsType, U}
    meta_ = isempty(meta) ? meta : _DELIMITER * meta
    T_ = replace(replace(strip_module_name(T), "{" => _DELIMITER), "}" => "")
    return Symbol("$(strip_module_name(string(U)))$(_DELIMITER)$(T_)" * meta_)
end

function check_meta_chars(meta::String)
    # Underscores in this field will prevent us from being able to decode keys.
    if occursin(_DELIMITER, meta)
        throw(InvalidValue("'$_DELIMITER' is not allowed in meta"))
    end
end

function should_write_resulting_value(key_val::OptimizationContainerKey)
    value_type = get_entry_type(key_val)
    return should_write_resulting_value(value_type)
end

function convert_result_to_natural_units(key::OptimizationContainerKey)
    return convert_result_to_natural_units(get_entry_type(key))
end

#### VariableKeys ####

struct VariableKey{T <: VariableType, U <: InfrastructureSystemsType} <:
       OptimizationContainerKey
    meta::String
end

function VariableKey(
    ::Type{T},
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: VariableType, U <: InfrastructureSystemsType}
    if isabstracttype(U)
        throw(ArgumentError("Type $U can't be abstract"))
    end
    check_meta_chars(meta)
    return VariableKey{T, U}(meta)
end

get_entry_type(
    ::VariableKey{T, U},
) where {T <: VariableType, U <: InfrastructureSystemsType} = T
get_component_type(
    ::VariableKey{T, U},
) where {T <: VariableType, U <: InfrastructureSystemsType} = U

#### ConstraintKey ####

struct ConstraintKey{T <: ConstraintType, U <: InfrastructureSystemsType} <:
       OptimizationContainerKey
    meta::String
end

function ConstraintKey(
    ::Type{T},
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: ConstraintType, U <: InfrastructureSystemsType}
    check_meta_chars(meta)
    return ConstraintKey{T, U}(meta)
end

get_entry_type(
    ::ConstraintKey{T, U},
) where {T <: ConstraintType, U <: InfrastructureSystemsType} = T
get_component_type(
    ::ConstraintKey{T, U},
) where {T <: ConstraintType, U <: InfrastructureSystemsType} = U

function encode_key(key::ConstraintKey)
    return encode_symbol(get_component_type(key), get_entry_type(key), key.meta)
end

Base.convert(::Type{ConstraintKey}, name::Symbol) = ConstraintKey(decode_symbol(name)...)

#### ExpressionKeys ####

struct ExpressionKey{T <: ExpressionType, U <: InfrastructureSystemsType} <:
       OptimizationContainerKey
    meta::String
end

function ExpressionKey(
    ::Type{T},
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: ExpressionType, U <: InfrastructureSystemsType}
    if isabstracttype(U)
        throw(ArgumentError("Type $U can't be abstract"))
    end
    check_meta_chars(meta)
    return ExpressionKey{T, U}(meta)
end

get_entry_type(
    ::ExpressionKey{T, U},
) where {T <: ExpressionType, U <: InfrastructureSystemsType} = T

get_component_type(
    ::ExpressionKey{T, U},
) where {T <: ExpressionType, U <: InfrastructureSystemsType} = U

function encode_key(key::ExpressionKey)
    return encode_symbol(get_component_type(key), get_entry_type(key), key.meta)
end

Base.convert(::Type{ExpressionKey}, name::Symbol) = ExpressionKey(decode_symbol(name)...)

#### AuxVariableKeys ####

struct AuxVarKey{T <: AuxVariableType, U <: InfrastructureSystemsType} <:
       OptimizationContainerKey
    meta::String
end

function AuxVarKey(
    ::Type{T},
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: AuxVariableType, U <: InfrastructureSystemsType}
    if isabstracttype(U)
        throw(ArgumentError("Type $U can't be abstract"))
    end
    return AuxVarKey{T, U}(meta)
end

get_entry_type(
    ::AuxVarKey{T, U},
) where {T <: AuxVariableType, U <: InfrastructureSystemsType} = T
get_component_type(
    ::AuxVarKey{T, U},
) where {T <: AuxVariableType, U <: InfrastructureSystemsType} = U

#### Initial Conditions Keys ####

struct InitialConditionKey{T <: InitialConditionType, U <: InfrastructureSystemsType} <:
       OptimizationContainerKey
    meta::String
end

function InitialConditionKey(
    ::Type{T},
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: InitialConditionType, U <: InfrastructureSystemsType}
    if isabstracttype(U)
        throw(ArgumentError("Type $U can't be abstract"))
    end
    return InitialConditionKey{T, U}(meta)
end

get_entry_type(
    ::InitialConditionKey{T, U},
) where {T <: InitialConditionType, U <: InfrastructureSystemsType} = T
get_component_type(
    ::InitialConditionKey{T, U},
) where {T <: InitialConditionType, U <: InfrastructureSystemsType} = U

#### Parameter Keys #####
struct ParameterKey{T <: ParameterType, U <: InfrastructureSystemsType} <:
       OptimizationContainerKey
    meta::String
end

function ParameterKey(
    ::Type{T},
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: ParameterType, U <: InfrastructureSystemsType}
    if isabstracttype(U)
        throw(ArgumentError("Type $U can't be abstract"))
    end
    check_meta_chars(meta)
    return ParameterKey{T, U}(meta)
end

get_entry_type(
    ::ParameterKey{T, U},
) where {T <: ParameterType, U <: InfrastructureSystemsType} = T
get_component_type(
    ::ParameterKey{T, U},
) where {T <: ParameterType, U <: InfrastructureSystemsType} = U
