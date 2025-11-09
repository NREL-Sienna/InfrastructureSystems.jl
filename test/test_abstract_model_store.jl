import InfrastructureSystems
const IS = InfrastructureSystems
import InfrastructureSystems.Optimization:
    get_store_container_type,
    get_data_field,
    list_fields,
    list_keys,
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
    store.variables[var_key] = [1.0 2.0; 3.0 4.0]
    @test !isempty(store)

    # Test empty!
    empty!(store)
    @test isempty(store)
end

@testset "Test MockModelStore get_data_field" begin
    store = MockModelStore()

    # Test getting each field
    @test isa(get_data_field(store, :variables), Dict)
    @test isa(get_data_field(store, :aux_variables), Dict)
    @test isa(get_data_field(store, :duals), Dict)
    @test isa(get_data_field(store, :parameters), Dict)
    @test isa(get_data_field(store, :expressions), Dict)

    # Verify they are the actual fields
    @test get_data_field(store, :variables) === store.variables
    @test get_data_field(store, :aux_variables) === store.aux_variables
    @test get_data_field(store, :duals) === store.duals
    @test get_data_field(store, :parameters) === store.parameters
    @test get_data_field(store, :expressions) === store.expressions
end

@testset "Test MockModelStore list_fields and list_keys" begin
    store = MockModelStore()

    var_key1 = VariableKey(MockVariable, IS.TestComponent)
    var_key2 = VariableKey(MockVariable2, IS.TestComponent)
    store.variables[var_key1] = [1.0 2.0; 3.0 4.0]
    store.variables[var_key2] = [5.0 6.0; 7.0 8.0]

    # Test list_fields
    fields = list_fields(store, :variables)
    @test var_key1 in fields
    @test var_key2 in fields

    # Test list_keys
    keys_list = list_keys(store, :variables)
    @test isa(keys_list, Vector)
    @test var_key1 in keys_list
    @test var_key2 in keys_list
end

@testset "Test MockModelStore get_value for VariableKey" begin
    store = MockModelStore()

    var_key = VariableKey(MockVariable, IS.TestComponent)
    test_data = [1.0 2.0; 3.0 4.0]
    store.variables[var_key] = test_data

    # Test get_value
    retrieved = get_value(store, MockVariable(), IS.TestComponent)
    @test retrieved == test_data
end

@testset "Test MockModelStore get_value for AuxVarKey" begin
    store = MockModelStore()

    aux_key = AuxVarKey(MockAuxVariable, IS.TestComponent)
    test_data = [10.0 20.0; 30.0 40.0]
    store.aux_variables[aux_key] = test_data

    # Test get_value
    retrieved = get_value(store, MockAuxVariable(), IS.TestComponent)
    @test retrieved == test_data
end

@testset "Test MockModelStore get_value for ConstraintKey" begin
    store = MockModelStore()

    constraint_key = ConstraintKey(MockConstraint, IS.TestComponent)
    test_data = [100.0 200.0; 300.0 400.0]
    store.duals[constraint_key] = test_data

    # Test get_value
    retrieved = get_value(store, MockConstraint(), IS.TestComponent)
    @test retrieved == test_data
end

@testset "Test MockModelStore get_value for ParameterKey" begin
    store = MockModelStore()

    param_key = ParameterKey(MockParameter, IS.TestComponent)
    test_data = [0.1 0.2; 0.3 0.4]
    store.parameters[param_key] = test_data

    # Test get_value
    retrieved = get_value(store, MockParameter(), IS.TestComponent)
    @test retrieved == test_data
end

@testset "Test MockModelStore get_value for ExpressionKey" begin
    store = MockModelStore()

    expr_key = ExpressionKey(MockExpression, IS.TestComponent)
    test_data = [1000.0 2000.0; 3000.0 4000.0]
    store.expressions[expr_key] = test_data

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

    store.variables[var_key] = [1.0]
    store.aux_variables[aux_key] = [2.0]
    store.duals[constraint_key] = [3.0]
    store.parameters[param_key] = [4.0]
    store.expressions[expr_key] = [5.0]

    @test !isempty(store)

    # Verify all data is stored
    @test length(list_keys(store, :variables)) == 1
    @test length(list_keys(store, :aux_variables)) == 1
    @test length(list_keys(store, :duals)) == 1
    @test length(list_keys(store, :parameters)) == 1
    @test length(list_keys(store, :expressions)) == 1

    # Test empty! clears everything
    empty!(store)
    @test isempty(store)
    @test length(list_keys(store, :variables)) == 0
    @test length(list_keys(store, :aux_variables)) == 0
    @test length(list_keys(store, :duals)) == 0
    @test length(list_keys(store, :parameters)) == 0
    @test length(list_keys(store, :expressions)) == 0
end
