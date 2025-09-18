import InfrastructureSystems.Optimization:
    OptimizationContainerMetadata,
    OptimizationProblemResults,
    VariableKey,
    ExpressionKey,
    read_variable,
    read_expression
import Dates:
    DateTime,
    Millisecond
const IS = InfrastructureSystems

@testset "Test OptimizationProblemResults long format" begin
    base_power = 10.0
    # 2 hours timestamp range
    timestamp_range =
        StepRange(
            DateTime("2024-01-01T00:00:00"),
            Millisecond(3600000),
            DateTime("2024-01-01T01:00:00"),
        )
    timestamp_vec = collect(timestamp_range)
    data = IS.SystemData()
    uuid = IS.make_uuid()
    aux_variable_values = Dict()
    @test !IS.Optimization.convert_result_to_natural_units(MockVariable)
    @test IS.Optimization.convert_result_to_natural_units(MockVariable2)
    var_key1 = VariableKey(MockVariable, IS.TestComponent)
    var_key2 = VariableKey(MockVariable2, IS.TestComponent)
    vals = [1.0, 2.0, 3.0, 4.0]
    variable_values = Dict(
        var_key1 => DataFrame(
            "time_index" => [1, 2, 1, 2],
            "name" => ["c1", "c1", "c2", "c2"],
            "value" => vals,
        ),
        var_key2 => DataFrame(
            "time_index" => [1, 2, 1, 2],
            "name" => ["c1", "c1", "c2", "c2"],
            "value" => vals,
        ),
    )
    dual_values = Dict()
    parameter_values = Dict()
    @test !IS.Optimization.convert_result_to_natural_units(MockExpression)
    @test IS.Optimization.convert_result_to_natural_units(MockExpression2)
    exp_key1 = ExpressionKey(MockExpression, IS.TestComponent)
    exp_key2 = ExpressionKey(MockExpression2, ThermalGenerator)
    # Expression only 1 time-step
    expression_values = Dict(
        exp_key1 => DataFrame(
            "time_index" => [1, 2, 1, 2],
            "name" => ["c1", "c1", "c2", "c2"],
            "value" => vals,
        ),
        exp_key2 => DataFrame(
            "time_index" => [1, 2, 1, 2],
            "custom_name" => ["c1", "c1", "c2", "c2"],
            "value" => vals,
        ),
    )
    optimizer_stats = DataFrames.DataFrame()
    metadata = OptimizationContainerMetadata()
    # Test with StepRange
    opt_res1 = OptimizationProblemResults(
        base_power,
        timestamp_range,
        data,
        uuid,
        aux_variable_values,
        variable_values,
        dual_values,
        parameter_values,
        expression_values,
        optimizer_stats,
        metadata,
        "test_model",
        mktempdir(),
        mktempdir(),
    )
    # Test with Vector{DateTime}
    opt_res2 = OptimizationProblemResults(
        base_power,
        timestamp_vec,
        data,
        uuid,
        aux_variable_values,
        variable_values,
        dual_values,
        parameter_values,
        expression_values,
        optimizer_stats,
        metadata,
        "test_model",
        mktempdir(),
        mktempdir(),
    )
    timestamp_vec2 = deepcopy(timestamp_vec)
    pop!(timestamp_vec2)
    opt_res3 = OptimizationProblemResults(
        base_power,
        timestamp_vec2,
        data,
        uuid,
        aux_variable_values,
        variable_values,
        dual_values,
        parameter_values,
        expression_values,
        optimizer_stats,
        metadata,
        "test_model",
        mktempdir(),
        mktempdir(),
    )

    var_res = read_variable(opt_res1, var_key1)
    @test sort!(unique(var_res.DateTime)) == timestamp_vec
    @test @rsubset(var_res, :name == "c1")[!, :value] == [1.0, 2.0]
    @test @rsubset(var_res, :name == "c2")[!, :value] == [3.0, 4.0]

    var_res = read_variable(opt_res1, var_key2)
    @test @rsubset(var_res, :name == "c1")[!, :value] == [10.0, 20.0]
    @test @rsubset(var_res, :name == "c2")[!, :value] == [30.0, 40.0]

    var_res = read_variable(opt_res1, var_key2; table_format = IS.TableFormat.WIDE)
    @test var_res[!, :c1] == [10.0, 20.0]
    @test var_res[!, :c2] == [30.0, 40.0]

    exp_res = read_expression(opt_res2, exp_key1)
    @test @rsubset(exp_res, :name == "c1")[!, :value] == [1.0, 2.0]
    @test @rsubset(exp_res, :name == "c2")[!, :value] == [3.0, 4.0]
    exp_res = read_expression(opt_res2, exp_key2)
    @show exp_res
    @test @rsubset(exp_res, :custom_name == "c1")[!, :value] == [10.0, 20.0]
    @test @rsubset(exp_res, :custom_name == "c2")[!, :value] == [30.0, 40.0]

    @test IS.Optimization.get_resolution(opt_res1) == Millisecond(3600000)
    @test IS.Optimization.get_resolution(opt_res2) == Millisecond(3600000)
    @test isnothing(IS.Optimization.get_resolution(opt_res3))
end
