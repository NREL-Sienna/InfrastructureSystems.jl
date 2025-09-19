struct MockContainer <: IS.Optimization.AbstractOptimizationContainer end
struct MockVariable <: IS.Optimization.VariableType end
struct MockVariable2 <: IS.Optimization.VariableType end
struct MockConstraint <: IS.Optimization.ConstraintType end
struct MockAuxVariable <: IS.Optimization.AuxVariableType end
struct MockExpression <: IS.Optimization.ExpressionType end
struct MockExpression2 <: IS.Optimization.ExpressionType end
struct MockParameter <: IS.Optimization.ParameterType end
struct MockInitialCondition <: IS.Optimization.InitialConditionType end

IS.Optimization.convert_result_to_natural_units(::Type{MockVariable2}) = true
IS.Optimization.should_write_resulting_value(::Type{MockVariable2}) = false
IS.Optimization.convert_result_to_natural_units(::Type{MockExpression2}) = true
IS.Optimization.should_write_resulting_value(::Type{MockExpression2}) = false
IS.Optimization.get_first_dimension_result_column_name(
    ::IS.Optimization.ExpressionKey{MockExpression2, ThermalGenerator},
) = "custom_name"

struct MockStoreParams <: IS.Optimization.AbstractModelStoreParams
    size::Integer
end

struct MockModelStore <: IS.Optimization.AbstractModelStore
    duals::Dict{IS.Optimization.ConstraintKey, Matrix{Float64}}
    parameters::Dict{IS.Optimization.ParameterKey, Matrix{Float64}}
    variables::Dict{IS.Optimization.VariableKey, Matrix{Float64}}
    aux_variables::Dict{IS.Optimization.AuxVarKey, Matrix{Float64}}
    expressions::Dict{IS.Optimization.ExpressionKey, Matrix{Float64}}
end

function MockModelStore()
    return MockModelStore(
        Dict{IS.Optimization.ConstraintKey, Matrix{Float64}}(),
        Dict{IS.Optimization.ParameterKey, Matrix{Float64}}(),
        Dict{IS.Optimization.VariableKey, Matrix{Float64}}(),
        Dict{IS.Optimization.AuxVarKey, Matrix{Float64}}(),
        Dict{IS.Optimization.ExpressionKey, Matrix{Float64}}(),
    )
end

function IS.Optimization.read_optimizer_stats(store::MockModelStore)
    stats = [IS.Optimization.to_namedtuple(x) for x in values(store.optimizer_stats)]
    df = DataFrames.DataFrame(stats)
    DataFrames.insertcols!(df, 1, :DateTime => keys(store.optimizer_stats))
    return df
end
