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
) where {T <: InfrastructureSystemsComponent, U}
    meta_ = isempty(meta) ? meta : _DELIMITER * meta
    T_ = replace(replace(strip_module_name(T), "{" => _DELIMITER), "}" => "")
    return Symbol("$(strip_module_name(string(U)))$(_DELIMITER)$(T_)" * meta_)
end

function check_meta_chars(meta)
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

struct VariableKey{T <: VariableType, U <: InfrastructureSystemsComponent} <:
       OptimizationContainerKey
    meta::String
end

function VariableKey(
    ::Type{T},
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: VariableType, U <: InfrastructureSystemsComponent}
    if isabstracttype(U)
        error("Type $U can't be abstract")
    end
    check_meta_chars(meta)
    return VariableKey{T, U}(meta)
end

function VariableKey(
    ::Type{T},
    meta::String = CONTAINER_KEY_EMPTY_META,
) where {T <: VariableType}
    return VariableKey(T, InfrastructureSystemsComponent, meta)
end

get_entry_type(
    ::VariableKey{T, U},
) where {T <: VariableType, U <: InfrastructureSystemsComponent} = T
get_component_type(
    ::VariableKey{T, U},
) where {T <: VariableType, U <: InfrastructureSystemsComponent} = U

#### ConstraintKey ####

struct ConstraintKey{T <: ConstraintType, U <: InfrastructureSystemsComponent} <:
       OptimizationContainerKey
    meta::String
end

function ConstraintKey(
    ::Type{T},
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: ConstraintType, U <: InfrastructureSystemsComponent}
    check_meta_chars(meta)
    return ConstraintKey{T, U}(meta)
end

get_entry_type(
    ::ConstraintKey{T, U},
) where {T <: ConstraintType, U <: InfrastructureSystemsComponent} = T
get_component_type(
    ::ConstraintKey{T, U},
) where {T <: ConstraintType, U <: InfrastructureSystemsComponent} = U

function encode_key(key::ConstraintKey)
    return encode_symbol(get_component_type(key), get_entry_type(key), key.meta)
end

Base.convert(::Type{ConstraintKey}, name::Symbol) = ConstraintKey(decode_symbol(name)...)

#### ExpressionKeys ####

struct ExpressionKey{T <: ExpressionType, U <: InfrastructureSystemsComponent} <:
       OptimizationContainerKey
    meta::String
end

function ExpressionKey(
    ::Type{T},
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: ExpressionType, U <: InfrastructureSystemsComponent}
    if isabstracttype(U)
        error("Type $U can't be abstract")
    end
    check_meta_chars(meta)
    return ExpressionKey{T, U}(meta)
end

get_entry_type(
    ::ExpressionKey{T, U},
) where {T <: ExpressionType, U <: InfrastructureSystemsComponent} = T

get_component_type(
    ::ExpressionKey{T, U},
) where {T <: ExpressionType, U <: InfrastructureSystemsComponent} = U

function encode_key(key::ExpressionKey)
    return encode_symbol(get_component_type(key), get_entry_type(key), key.meta)
end

Base.convert(::Type{ExpressionKey}, name::Symbol) = ExpressionKey(decode_symbol(name)...)

#### AuxVariableKeys ####

struct AuxVarKey{T <: AuxVariableType, U <: InfrastructureSystemsComponent} <:
       OptimizationContainerKey
    meta::String
end

function AuxVarKey(
    ::Type{T},
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: AuxVariableType, U <: InfrastructureSystemsComponent}
    if isabstracttype(U)
        error("Type $U can't be abstract")
    end
    return AuxVarKey{T, U}(meta)
end

get_entry_type(
    ::AuxVarKey{T, U},
) where {T <: AuxVariableType, U <: InfrastructureSystemsComponent} = T
get_component_type(
    ::AuxVarKey{T, U},
) where {T <: AuxVariableType, U <: InfrastructureSystemsComponent} = U

#### Initial Conditions Keys ####

struct ICKey{T <: InitialConditionType, U <: InfrastructureSystemsComponent} <:
       OptimizationContainerKey
    meta::String
end

function ICKey(
    ::Type{T},
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: InitialConditionType, U <: InfrastructureSystemsComponent}
    if isabstracttype(U)
        error("Type $U can't be abstract")
    end
    return ICKey{T, U}(meta)
end

get_entry_type(
    ::ICKey{T, U},
) where {T <: InitialConditionType, U <: InfrastructureSystemsComponent} = T
get_component_type(
    ::ICKey{T, U},
) where {T <: InitialConditionType, U <: InfrastructureSystemsComponent} = U

#### Parameter Keys #####
struct ParameterKey{T <: ParameterType, U <: InfrastructureSystemsComponent} <:
       OptimizationContainerKey
    meta::String
end

function ParameterKey(
    ::Type{T},
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: ParameterType, U <: InfrastructureSystemsComponent}
    if isabstracttype(U)
        error("Type $U can't be abstract")
    end
    check_meta_chars(meta)
    return ParameterKey{T, U}(meta)
end

function ParameterKey(
    ::Type{T},
    meta::String = CONTAINER_KEY_EMPTY_META,
) where {T <: ParameterType}
    return ParameterKey(T, InfrastructureSystemsComponent, meta)
end

get_entry_type(
    ::ParameterKey{T, U},
) where {T <: ParameterType, U <: InfrastructureSystemsComponent} = T
get_component_type(
    ::ParameterKey{T, U},
) where {T <: ParameterType, U <: InfrastructureSystemsComponent} = U
