import InfrastructureSystems
const IS = InfrastructureSystems
import InfrastructureSystems.Optimization:
    OptimizationProblemResultsExport,
    VariableKey,
    AuxVarKey,
    ConstraintKey,
    ParameterKey,
    ExpressionKey,
    get_name,
    get_duals_set,
    get_expressions_set,
    get_parameters_set,
    get_variables_set,
    get_aux_variables_set,
    get_optimizer_stats_flag,
    get_store_all_flags,
    should_export_dual,
    should_export_expression,
    should_export_parameter,
    should_export_variable,
    should_export_aux_variable

@testset "Test OptimizationProblemResultsExport basic constructor" begin
    exports = OptimizationProblemResultsExport(:TestProblem)

    @test get_name(exports) == :TestProblem
    @test isempty(get_duals_set(exports))
    @test isempty(get_expressions_set(exports))
    @test isempty(get_parameters_set(exports))
    @test isempty(get_variables_set(exports))
    @test isempty(get_aux_variables_set(exports))
    @test get_optimizer_stats_flag(exports) == true
    @test get_store_all_flags(exports)[:duals] == false
    @test get_store_all_flags(exports)[:expressions] == false
    @test get_store_all_flags(exports)[:parameters] == false
    @test get_store_all_flags(exports)[:variables] == false
    @test get_store_all_flags(exports)[:aux_variables] == false
end

@testset "Test OptimizationProblemResultsExport with specific keys" begin
    var_key = VariableKey(MockVariable, IS.TestComponent)
    dual_key = ConstraintKey(MockConstraint, IS.TestComponent)
    expr_key = ExpressionKey(MockExpression, IS.TestComponent)
    param_key = ParameterKey(MockParameter, IS.TestComponent)
    aux_key = AuxVarKey(MockAuxVariable, IS.TestComponent)

    exports = OptimizationProblemResultsExport(
        :TestProblem;
        variables = [var_key],
        duals = [dual_key],
        expressions = [expr_key],
        parameters = [param_key],
        aux_variables = [aux_key],
        optimizer_stats = false,
    )

    @test get_name(exports) == :TestProblem
    @test var_key in get_variables_set(exports)
    @test dual_key in get_duals_set(exports)
    @test expr_key in get_expressions_set(exports)
    @test param_key in get_parameters_set(exports)
    @test aux_key in get_aux_variables_set(exports)
    @test get_optimizer_stats_flag(exports) == false
end

@testset "Test OptimizationProblemResultsExport with store_all flags" begin
    exports = OptimizationProblemResultsExport(
        :TestProblem;
        store_all_duals = true,
        store_all_expressions = true,
        store_all_parameters = true,
        store_all_variables = true,
        store_all_aux_variables = true,
    )

    @test get_store_all_flags(exports)[:duals] == true
    @test get_store_all_flags(exports)[:expressions] == true
    @test get_store_all_flags(exports)[:parameters] == true
    @test get_store_all_flags(exports)[:variables] == true
    @test get_store_all_flags(exports)[:aux_variables] == true
end

@testset "Test OptimizationProblemResultsExport should_export functions" begin
    var_key1 = VariableKey(MockVariable, IS.TestComponent)
    var_key2 = VariableKey(MockVariable2, IS.TestComponent)

    # Test with specific keys
    exports = OptimizationProblemResultsExport(
        :TestProblem;
        variables = [var_key1],
    )

    @test should_export_variable(exports, var_key1) == true
    @test should_export_variable(exports, var_key2) == false

    # Test with store_all flag
    exports_all = OptimizationProblemResultsExport(
        :TestProblem;
        store_all_variables = true,
    )

    @test should_export_variable(exports_all, var_key1) == true
    @test should_export_variable(exports_all, var_key2) == true
end

@testset "Test OptimizationProblemResultsExport should_export_dual" begin
    dual_key1 = ConstraintKey(MockConstraint, IS.TestComponent)
    dual_key2 = ConstraintKey(MockConstraint, ThermalGenerator)

    exports = OptimizationProblemResultsExport(
        :TestProblem;
        duals = [dual_key1],
    )

    @test should_export_dual(exports, dual_key1) == true
    @test should_export_dual(exports, dual_key2) == false

    # Test with store_all flag
    exports_all = OptimizationProblemResultsExport(
        :TestProblem;
        store_all_duals = true,
    )

    @test should_export_dual(exports_all, dual_key1) == true
    @test should_export_dual(exports_all, dual_key2) == true
end

@testset "Test OptimizationProblemResultsExport should_export_expression" begin
    expr_key1 = ExpressionKey(MockExpression, IS.TestComponent)
    expr_key2 = ExpressionKey(MockExpression2, IS.TestComponent)

    exports = OptimizationProblemResultsExport(
        :TestProblem;
        expressions = [expr_key1],
    )

    @test should_export_expression(exports, expr_key1) == true
    @test should_export_expression(exports, expr_key2) == false

    # Test with store_all flag
    exports_all = OptimizationProblemResultsExport(
        :TestProblem;
        store_all_expressions = true,
    )

    @test should_export_expression(exports_all, expr_key1) == true
    @test should_export_expression(exports_all, expr_key2) == true
end

@testset "Test OptimizationProblemResultsExport should_export_parameter" begin
    param_key1 = ParameterKey(MockParameter, IS.TestComponent)
    param_key2 = ParameterKey(MockParameter, ThermalGenerator)

    exports = OptimizationProblemResultsExport(
        :TestProblem;
        parameters = [param_key1],
    )

    @test should_export_parameter(exports, param_key1) == true
    @test should_export_parameter(exports, param_key2) == false

    # Test with store_all flag
    exports_all = OptimizationProblemResultsExport(
        :TestProblem;
        store_all_parameters = true,
    )

    @test should_export_parameter(exports_all, param_key1) == true
    @test should_export_parameter(exports_all, param_key2) == true
end

@testset "Test OptimizationProblemResultsExport should_export_aux_variable" begin
    aux_key1 = AuxVarKey(MockAuxVariable, IS.TestComponent)
    aux_key2 = AuxVarKey(MockAuxVariable, ThermalGenerator)

    exports = OptimizationProblemResultsExport(
        :TestProblem;
        aux_variables = [aux_key1],
    )

    @test should_export_aux_variable(exports, aux_key1) == true
    @test should_export_aux_variable(exports, aux_key2) == false

    # Test with store_all flag
    exports_all = OptimizationProblemResultsExport(
        :TestProblem;
        store_all_aux_variables = true,
    )

    @test should_export_aux_variable(exports_all, aux_key1) == true
    @test should_export_aux_variable(exports_all, aux_key2) == true
end

@testset "Test OptimizationProblemResultsExport with mixed settings" begin
    var_key = VariableKey(MockVariable, IS.TestComponent)
    dual_key = ConstraintKey(MockConstraint, IS.TestComponent)

    exports = OptimizationProblemResultsExport(
        :TestProblem;
        variables = [var_key],
        store_all_duals = true,
        store_all_expressions = true,
        optimizer_stats = false,
    )

    @test should_export_variable(exports, var_key) == true
    @test should_export_dual(exports, dual_key) == true  # store_all is true
    @test get_optimizer_stats_flag(exports) == false

    # Test keys not explicitly added
    expr_key = ExpressionKey(MockExpression, IS.TestComponent)
    @test should_export_expression(exports, expr_key) == true  # store_all is true

    param_key = ParameterKey(MockParameter, IS.TestComponent)
    @test should_export_parameter(exports, param_key) == false  # store_all is false
end

@testset "Test OptimizationProblemResultsExport with Sets" begin
    var_key1 = VariableKey(MockVariable, IS.TestComponent)
    var_key2 = VariableKey(MockVariable2, IS.TestComponent)

    # Test with Set input
    exports = OptimizationProblemResultsExport(
        :TestProblem;
        variables = Set([var_key1, var_key2]),
    )

    @test isa(get_variables_set(exports), Set)
    @test var_key1 in get_variables_set(exports)
    @test var_key2 in get_variables_set(exports)
end

@testset "Test OptimizationProblemResultsExport with Vector input" begin
    var_key1 = VariableKey(MockVariable, IS.TestComponent)
    var_key2 = VariableKey(MockVariable2, IS.TestComponent)

    # Test with Vector input (should be converted to Set)
    exports = OptimizationProblemResultsExport(
        :TestProblem;
        variables = [var_key1, var_key2],
    )

    @test isa(get_variables_set(exports), Set)
    @test var_key1 in get_variables_set(exports)
    @test var_key2 in get_variables_set(exports)
end

@testset "Test OptimizationProblemResultsExport name as Symbol" begin
    # Test with String name (should be converted to Symbol)
    exports = OptimizationProblemResultsExport("TestProblemString")

    @test get_name(exports) isa Symbol
    @test get_name(exports) == :TestProblemString
end
