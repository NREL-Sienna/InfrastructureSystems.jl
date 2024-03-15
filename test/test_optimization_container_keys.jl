import InfrastructureSystems.Optimization:
    VariableKey,
    ConstraintKey,
    AuxVarKey,
    ExpressionKey,
    ParameterKey,
    InitialConditionKey

@testset "Test optimization container keys" begin
    var_key = VariableKey(IS.Optimization.MockVariable, IS.TestComponent)
    @test IS.Optimization.encode_key(var_key) ==
          Symbol("Optimization.MockVariable__TestComponent")
    constraint_key = ConstraintKey(IS.Optimization.MockConstraint, IS.TestComponent)
    @test IS.Optimization.encode_key(constraint_key) ==
          Symbol("Optimization.MockConstraint__TestComponent")
    auxvar_key = AuxVarKey(IS.Optimization.MockAuxVariable, IS.TestComponent)
    @test IS.Optimization.encode_key(auxvar_key) ==
          Symbol("Optimization.MockAuxVariable__TestComponent")
    expression_key = ExpressionKey(IS.Optimization.MockExpresssion, IS.TestComponent)
    @test IS.Optimization.encode_key(expression_key) ==
          Symbol("Optimization.MockExpresssion__TestComponent")
    parameter_key = ParameterKey(IS.Optimization.MockParameter, IS.TestComponent)
    @test IS.Optimization.encode_key(parameter_key) ==
          Symbol("Optimization.MockParameter__TestComponent")
    ic_key = InitialConditionKey(IS.Optimization.MockInitialCondition, IS.TestComponent)
    @test IS.Optimization.encode_key(ic_key) ==
          Symbol("Optimization.MockInitialCondition__TestComponent")

    @test_throws ArgumentError VariableKey(
        IS.Optimization.MockVariable,
        IS.InfrastructureSystemsType,
    )
    @test_throws IS.InvalidValue IS.Optimization.check_meta_chars("ZZ__CC")
end
