import InfrastructureSystems
const IS = InfrastructureSystems
import InfrastructureSystems.Optimization:
    get_store_container_type,
    get_variables_container,
    get_aux_variables_container,
    get_duals_container,
    get_parameters_container,
    get_expressions_container,
    list_variable_keys,
    list_aux_variable_keys,
    list_dual_keys,
    list_parameter_keys,
    list_expression_keys,
    get_value,
    VariableKey,
    AuxVarKey,
    ConstraintKey,
    ParameterKey,
    ExpressionKey,
    STORE_CONTAINER_DUALS,
    STORE_CONTAINER_PARAMETERS,
    STORE_CONTAINER_VARIABLES,
    STORE_CONTAINER_AUX_VARIABLES,
    STORE_CONTAINER_EXPRESSIONS

@testset "Test get_store_container_type" begin
    # Test for each key type
    var_key = VariableKey(MockVariable, IS.TestComponent)
    @test get_store_container_type(var_key) == STORE_CONTAINER_VARIABLES

    aux_key = AuxVarKey(MockAuxVariable, IS.TestComponent)
    @test get_store_container_type(aux_key) == STORE_CONTAINER_AUX_VARIABLES

    constraint_key = ConstraintKey(MockConstraint, IS.TestComponent)
    @test get_store_container_type(constraint_key) == STORE_CONTAINER_DUALS

    param_key = ParameterKey(MockParameter, IS.TestComponent)
    @test get_store_container_type(param_key) == STORE_CONTAINER_PARAMETERS

    expr_key = ExpressionKey(MockExpression, IS.TestComponent)
    @test get_store_container_type(expr_key) == STORE_CONTAINER_EXPRESSIONS
end

@testset "Test MockModelStore empty and isempty" begin
    store = MockModelStore()

    # Test isempty on new store
    @test isempty(store)

    # Add some data
    var_key = VariableKey(MockVariable, IS.TestComponent)
    get_variables_container(store)[var_key] = [1.0 2.0; 3.0 4.0]
    @test !isempty(store)

    # Test empty!
    empty!(store)
    @test isempty(store)
end

@testset "Test MockModelStore container getters" begin
    store = MockModelStore()

    # Test getting each container
    @test isa(get_variables_container(store), Dict)
    @test isa(get_aux_variables_container(store), Dict)
    @test isa(get_duals_container(store), Dict)
    @test isa(get_parameters_container(store), Dict)
    @test isa(get_expressions_container(store), Dict)

    # Verify getters return the actual container fields
    @test get_variables_container(store) === store.variables
    @test get_aux_variables_container(store) === store.aux_variables
    @test get_duals_container(store) === store.duals
    @test get_parameters_container(store) === store.parameters
    @test get_expressions_container(store) === store.expressions
end

@testset "Test MockModelStore list functions" begin
    store = MockModelStore()

    var_key1 = VariableKey(MockVariable, IS.TestComponent)
    var_key2 = VariableKey(MockVariable2, IS.TestComponent)
    get_variables_container(store)[var_key1] = [1.0 2.0; 3.0 4.0]
    get_variables_container(store)[var_key2] = [5.0 6.0; 7.0 8.0]

    # Test list_variable_keys
    keys_list = list_variable_keys(store)
    @test isa(keys_list, Vector)
    @test var_key1 in keys_list
    @test var_key2 in keys_list
    @test length(keys_list) == 2
end

@testset "Test MockModelStore get_value for VariableKey" begin
    store = MockModelStore()

    var_key = VariableKey(MockVariable, IS.TestComponent)
    test_data = [1.0 2.0; 3.0 4.0]
    get_variables_container(store)[var_key] = test_data

    # Test get_value
    retrieved = get_value(store, MockVariable(), IS.TestComponent)
    @test retrieved == test_data
end

@testset "Test MockModelStore get_value for AuxVarKey" begin
    store = MockModelStore()

    aux_key = AuxVarKey(MockAuxVariable, IS.TestComponent)
    test_data = [10.0 20.0; 30.0 40.0]
    get_aux_variables_container(store)[aux_key] = test_data

    # Test get_value
    retrieved = get_value(store, MockAuxVariable(), IS.TestComponent)
    @test retrieved == test_data
end

@testset "Test MockModelStore get_value for ConstraintKey" begin
    store = MockModelStore()

    constraint_key = ConstraintKey(MockConstraint, IS.TestComponent)
    test_data = [100.0 200.0; 300.0 400.0]
    get_duals_container(store)[constraint_key] = test_data

    # Test get_value
    retrieved = get_value(store, MockConstraint(), IS.TestComponent)
    @test retrieved == test_data
end

@testset "Test MockModelStore get_value for ParameterKey" begin
    store = MockModelStore()

    param_key = ParameterKey(MockParameter, IS.TestComponent)
    test_data = [0.1 0.2; 0.3 0.4]
    get_parameters_container(store)[param_key] = test_data

    # Test get_value
    retrieved = get_value(store, MockParameter(), IS.TestComponent)
    @test retrieved == test_data
end

@testset "Test MockModelStore get_value for ExpressionKey" begin
    store = MockModelStore()

    expr_key = ExpressionKey(MockExpression, IS.TestComponent)
    test_data = [1000.0 2000.0; 3000.0 4000.0]
    get_expressions_container(store)[expr_key] = test_data

    # Test get_value
    retrieved = get_value(store, MockExpression(), IS.TestComponent)
    @test retrieved == test_data
end

@testset "Test MockModelStore with multiple keys" begin
    store = MockModelStore()

    # Add multiple different types
    var_key = VariableKey(MockVariable, IS.TestComponent)
    aux_key = AuxVarKey(MockAuxVariable, IS.TestComponent)
    constraint_key = ConstraintKey(MockConstraint, IS.TestComponent)
    param_key = ParameterKey(MockParameter, IS.TestComponent)
    expr_key = ExpressionKey(MockExpression, IS.TestComponent)

    get_variables_container(store)[var_key] = [1.0;;]
    get_aux_variables_container(store)[aux_key] = [2.0;;]
    get_duals_container(store)[constraint_key] = [3.0;;]
    get_parameters_container(store)[param_key] = [4.0;;]
    get_expressions_container(store)[expr_key] = [5.0;;]

    @test !isempty(store)

    # Verify all data is stored using specific list functions
    @test length(list_variable_keys(store)) == 1
    @test length(list_aux_variable_keys(store)) == 1
    @test length(list_dual_keys(store)) == 1
    @test length(list_parameter_keys(store)) == 1
    @test length(list_expression_keys(store)) == 1

    # Test empty! clears everything
    empty!(store)
    @test isempty(store)
    @test length(list_variable_keys(store)) == 0
    @test length(list_aux_variable_keys(store)) == 0
    @test length(list_dual_keys(store)) == 0
    @test length(list_parameter_keys(store)) == 0
    @test length(list_expression_keys(store)) == 0
end
