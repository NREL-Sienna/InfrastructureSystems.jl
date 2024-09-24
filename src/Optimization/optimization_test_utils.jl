struct MockContainer <: AbstractOptimizationContainer end

struct MockVariable <: VariableType end
struct MockConstraint <: ConstraintType end
struct MockAuxVariable <: AuxVariableType end
struct MockExpression <: ExpressionType end
struct MockParameter <: ParameterType end
struct MockInitialCondition <: InitialConditionType end

struct MockVariable2 <: VariableType end
convert_result_to_natural_units(::Type{MockVariable2}) = true
should_write_resulting_value(::Type{MockVariable2}) = false

struct MockStoreParams <: AbstractModelStoreParams
    size::Integer
end

struct MockModelStore <: AbstractModelStore
    duals::Dict{ConstraintKey, Matrix{Float64}}
    parameters::Dict{ParameterKey, Matrix{Float64}}
    variables::Dict{VariableKey, Matrix{Float64}}
    aux_variables::Dict{AuxVarKey, Matrix{Float64}}
    expressions::Dict{ExpressionKey, Matrix{Float64}}
end

function MockModelStore()
    return MockModelStore(
        Dict{ConstraintKey, Matrix{Float64}}(),
        Dict{ParameterKey, Matrix{Float64}}(),
        Dict{VariableKey, Matrix{Float64}}(),
        Dict{AuxVarKey, Matrix{Float64}}(),
        Dict{ExpressionKey, Matrix{Float64}}(),
    )
end

function initialize_storage!(
    store::MockModelStore,
    container::AbstractOptimizationContainer,
    params::MockStoreParams,
)
end

function write_result!(
    store::MockModelStore,
    name::Symbol,
    key::OptimizationContainerKey,
    index::Int,
    update_timestamp::Dates.DateTime,
    array::Vector{Float64},
)
end

function read_results(
    store::MockModelStore,
    key::OptimizationContainerKey;
    index::Int)
end

function write_optimizer_stats!(
    store::MockModelStore,
    stats::OptimizerStats,
    index::Int,
)
    if index in keys(store.optimizer_stats)
        @warn "Overwriting optimizer stats"
    end
    store.optimizer_stats[index] = stats
    return
end

function read_optimizer_stats(store::MockModelStore)
    stats = [to_namedtuple(x) for x in values(store.optimizer_stats)]
    df = DataFrames.DataFrame(stats)
    DataFrames.insertcols!(df, 1, :DateTime => keys(store.optimizer_stats))
    return df
end
