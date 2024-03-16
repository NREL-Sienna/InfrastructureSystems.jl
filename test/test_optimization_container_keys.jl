import InfrastructureSystems.Optimization:
    VariableKey,
    ConstraintKey,
    AuxVarKey,
    ExpressionKey,
    ParameterKey,
    InitialConditionKey
const IS = InfrastructureSystems
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
    expression_key = ExpressionKey(IS.Optimization.MockExpression, IS.TestComponent)
    @test IS.Optimization.encode_key(expression_key) ==
          Symbol("Optimization.MockExpression__TestComponent")
    parameter_key = ParameterKey(IS.Optimization.MockParameter, IS.TestComponent)
    @test IS.Optimization.encode_key(parameter_key) ==
          Symbol("Optimization.MockParameter__TestComponent")
    ic_key = InitialConditionKey(IS.Optimization.MockInitialCondition, IS.TestComponent)
    @test IS.Optimization.encode_key(ic_key) ==
          Symbol("Optimization.MockInitialCondition__TestComponent")

    @test_throws ArgumentError ExpressionKey(
        IS.Optimization.MockExpression,
        IS.InfrastructureSystemsType,
    )

    @test_throws ArgumentError AuxVarKey(
        IS.Optimization.MockAuxVariable,
        IS.InfrastructureSystemsType,
    )

    # Not tested because it is allowed.
    #@test_throws ArgumentError ConstraintKey(
    #    IS.Optimization.MockConstraint,
    #    IS.InfrastructureSystemsType,
    #)

    @test_throws ArgumentError VariableKey(
        IS.Optimization.MockVariable,
        IS.InfrastructureSystemsType,
    )

    @test_throws ArgumentError ParameterKey(
        IS.Optimization.MockParameter,
        IS.InfrastructureSystemsType,
    )

    @test_throws IS.InvalidValue IS.Optimization.check_meta_chars("ZZ__CC")

    @test !IS.Optimization.convert_result_to_natural_units(var_key)
    @test IS.Optimization.should_write_resulting_value(var_key)
    var_key2 = VariableKey(IS.Optimization.MockVariable2, IS.TestComponent)
    @test IS.Optimization.convert_result_to_natural_units(var_key2)
    @test !IS.Optimization.should_write_resulting_value(var_key2)

    key_strings = IS.Optimization.encode_keys_as_strings([var_key, var_key2])
    @test isa(key_strings, Vector{String})

    made_key = IS.Optimization.make_key(
        VariableKey,
        IS.Optimization.MockVariable2,
        IS.TestComponent,
    )
    @test isa(made_key, VariableKey)
end
