import InfrastructureSystems
const IS = InfrastructureSystems
import InfrastructureSystems.Optimization:
    AbstractOptimizationContainer,
    VariableType,
    ConstraintType,
    AuxVariableType,
    ParameterType,
    InitialConditionType,
    ExpressionType,
    RightHandSideParameter,
    ObjectiveFunctionParameter,
    TimeSeriesParameter,
    convert_result_to_natural_units,
    should_write_resulting_value,
    ConstructStage,
    ArgumentConstructStage,
    ModelConstructStage

@testset "Test abstract type hierarchy" begin
    # Test that our mock types are subtypes of the abstract types
    @test MockContainer <: AbstractOptimizationContainer
    @test MockVariable <: VariableType
    @test MockConstraint <: ConstraintType
    @test MockAuxVariable <: AuxVariableType
    @test MockParameter <: ParameterType
    @test MockInitialCondition <: InitialConditionType
    @test MockExpression <: ExpressionType
end

@testset "Test ParameterType hierarchy" begin
    @test RightHandSideParameter <: ParameterType
    @test ObjectiveFunctionParameter <: ParameterType
    @test TimeSeriesParameter <: RightHandSideParameter
end

@testset "Test ConstructStage types" begin
    @test ArgumentConstructStage <: ConstructStage
    @test ModelConstructStage <: ConstructStage

    # Test instantiation
    arg_stage = ArgumentConstructStage()
    model_stage = ModelConstructStage()
    @test isa(arg_stage, ArgumentConstructStage)
    @test isa(model_stage, ModelConstructStage)
end

@testset "Test convert_result_to_natural_units defaults" begin
    # Test default behavior for base types
    @test convert_result_to_natural_units(MockVariable) == false
    @test convert_result_to_natural_units(MockConstraint) == false
    @test convert_result_to_natural_units(MockAuxVariable) == false
    @test convert_result_to_natural_units(MockExpression) == false
    @test convert_result_to_natural_units(MockParameter) == false
end

@testset "Test convert_result_to_natural_units customized" begin
    # MockVariable2 has custom behavior defined in test/optimization.jl
    @test convert_result_to_natural_units(MockVariable2) == true

    # MockExpression2 has custom behavior defined in test/optimization.jl
    @test convert_result_to_natural_units(MockExpression2) == true
end

@testset "Test should_write_resulting_value defaults" begin
    # Test default behavior
    @test should_write_resulting_value(MockVariable) == true
    @test should_write_resulting_value(MockConstraint) == true
    @test should_write_resulting_value(MockAuxVariable) == true
    @test should_write_resulting_value(MockExpression) == false
    @test should_write_resulting_value(MockParameter) == false
end

@testset "Test should_write_resulting_value customized" begin
    # MockVariable2 has custom behavior defined in test/optimization.jl
    @test should_write_resulting_value(MockVariable2) == false

    # MockExpression2 has custom behavior defined in test/optimization.jl
    @test should_write_resulting_value(MockExpression2) == false
end

@testset "Test type instantiation" begin
    # Test that we can instantiate the mock types
    var = MockVariable()
    @test isa(var, MockVariable)
    @test isa(var, VariableType)

    constraint = MockConstraint()
    @test isa(constraint, MockConstraint)
    @test isa(constraint, ConstraintType)

    aux = MockAuxVariable()
    @test isa(aux, MockAuxVariable)
    @test isa(aux, AuxVariableType)

    param = MockParameter()
    @test isa(param, MockParameter)
    @test isa(param, ParameterType)

    ic = MockInitialCondition()
    @test isa(ic, MockInitialCondition)
    @test isa(ic, InitialConditionType)

    expr = MockExpression()
    @test isa(expr, MockExpression)
    @test isa(expr, ExpressionType)
end

@testset "Test multiple variable types" begin
    var1 = MockVariable()
    var2 = MockVariable2()

    @test isa(var1, VariableType)
    @test isa(var2, VariableType)
    @test typeof(var1) != typeof(var2)

    @test convert_result_to_natural_units(typeof(var1)) == false
    @test convert_result_to_natural_units(typeof(var2)) == true

    @test should_write_resulting_value(typeof(var1)) == true
    @test should_write_resulting_value(typeof(var2)) == false
end

@testset "Test multiple expression types" begin
    expr1 = MockExpression()
    expr2 = MockExpression2()

    @test isa(expr1, ExpressionType)
    @test isa(expr2, ExpressionType)
    @test typeof(expr1) != typeof(expr2)

    @test convert_result_to_natural_units(typeof(expr1)) == false
    @test convert_result_to_natural_units(typeof(expr2)) == true

    @test should_write_resulting_value(typeof(expr1)) == false
    @test should_write_resulting_value(typeof(expr2)) == false
end
