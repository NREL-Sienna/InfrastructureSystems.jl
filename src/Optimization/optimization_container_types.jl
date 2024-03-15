abstract type AbstractOptimizationContainer end

abstract type VariableType end
abstract type ConstraintType end
abstract type AuxVariableType end
abstract type ParameterType end
abstract type InitialConditionType end
abstract type ExpressionType end

"""
Optimization Container construction stage
"""
abstract type ConstructStage end

struct ArgumentConstructStage <: ConstructStage end
struct ModelConstructStage <: ConstructStage end