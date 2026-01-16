import InfrastructureSystems.Optimization:
    VariableKey,
    ConstraintKey,
    AuxVarKey,
    ExpressionKey,
    ParameterKey,
    InitialConditionKey
import InfrastructureSystems as IS
@testset "Test optimization container keys" begin
    var_key = VariableKey(MockVariable, IS.TestComponent)
    @test IS.Optimization.encode_key(var_key) == Symbol("MockVariable__TestComponent")
    constraint_key = ConstraintKey(MockConstraint, IS.TestComponent)
    @test IS.Optimization.encode_key(constraint_key) ==
          Symbol("MockConstraint__TestComponent")
    auxvar_key = AuxVarKey(MockAuxVariable, IS.TestComponent)
    @test IS.Optimization.encode_key(auxvar_key) == Symbol("MockAuxVariable__TestComponent")
    expression_key = ExpressionKey(MockExpression, IS.TestComponent)
    @test IS.Optimization.encode_key(expression_key) ==
          Symbol("MockExpression__TestComponent")
    parameter_key = ParameterKey(MockParameter, IS.TestComponent)
    @test IS.Optimization.encode_key(parameter_key) ==
          Symbol("MockParameter__TestComponent")
    ic_key = InitialConditionKey(MockInitialCondition, IS.TestComponent)
    @test IS.Optimization.encode_key(ic_key) ==
          Symbol("MockInitialCondition__TestComponent")

    @test_throws ArgumentError ExpressionKey(
        MockExpression,
        IS.InfrastructureSystemsType,
    )

    @test_throws ArgumentError AuxVarKey(
        MockAuxVariable,
        IS.InfrastructureSystemsType,
    )

    # Not tested because it is allowed.
    #@test_throws ArgumentError ConstraintKey(
    #    MockConstraint,
    #    IS.InfrastructureSystemsType,
    #)

    @test_throws ArgumentError VariableKey(
        MockVariable,
        IS.InfrastructureSystemsType,
    )

    @test_throws ArgumentError ParameterKey(
        MockParameter,
        IS.InfrastructureSystemsType,
    )

    @test_throws IS.InvalidValue IS.Optimization.check_meta_chars("ZZ__CC")

    @test !IS.Optimization.convert_result_to_natural_units(var_key)
    @test !IS.Optimization.convert_result_to_natural_units(constraint_key)
    @test !IS.Optimization.convert_result_to_natural_units(auxvar_key)
    @test !IS.Optimization.convert_result_to_natural_units(expression_key)
    @test !IS.Optimization.convert_result_to_natural_units(parameter_key)

    @test IS.Optimization.should_write_resulting_value(var_key)
    @test IS.Optimization.should_write_resulting_value(constraint_key)
    @test IS.Optimization.should_write_resulting_value(auxvar_key)
    @test !IS.Optimization.should_write_resulting_value(expression_key)
    @test !IS.Optimization.should_write_resulting_value(parameter_key)

    var_key2 = VariableKey(MockVariable2, IS.TestComponent)
    @test IS.Optimization.convert_result_to_natural_units(var_key2)
    @test !IS.Optimization.should_write_resulting_value(var_key2)

    key_strings = IS.Optimization.encode_keys_as_strings([var_key, var_key2])
    @test isa(key_strings, Vector{String})

    made_key = IS.Optimization.make_key(
        VariableKey,
        MockVariable2,
        IS.TestComponent,
    )
    @test isa(made_key, VariableKey)
end
