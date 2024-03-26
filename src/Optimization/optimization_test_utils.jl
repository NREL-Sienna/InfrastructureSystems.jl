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
