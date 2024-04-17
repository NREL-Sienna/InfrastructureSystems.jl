abstract type AbstractOptimizationContainer end

abstract type VariableType end
abstract type ConstraintType end
abstract type AuxVariableType end
abstract type ParameterType end
abstract type InitialConditionType end
abstract type ExpressionType end

convert_result_to_natural_units(::Type{<:VariableType}) = false
convert_result_to_natural_units(::Type{<:ConstraintType}) = false
convert_result_to_natural_units(::Type{<:AuxVariableType}) = false
convert_result_to_natural_units(::Type{<:ExpressionType}) = false
convert_result_to_natural_units(::Type{<:ParameterType}) = false

should_write_resulting_value(::Type{<:VariableType}) = true
should_write_resulting_value(::Type{<:ConstraintType}) = true
should_write_resulting_value(::Type{<:AuxVariableType}) = true
should_write_resulting_value(::Type{<:ExpressionType}) = true
should_write_resulting_value(::Type{<:ParameterType}) = true

abstract type RightHandSideParameter <: ParameterType end
abstract type ObjectiveFunctionParameter <: ParameterType end

abstract type TimeSeriesParameter <: RightHandSideParameter end

"""
Optimization Container construction stage
"""
abstract type ConstructStage end

struct ArgumentConstructStage <: ConstructStage end
struct ModelConstructStage <: ConstructStage end
