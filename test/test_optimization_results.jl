import InfrastructureSystems.Optimization:
    OptimizationContainerMetadata,
    OptimizationProblemResults,
    VariableKey,
    ExpressionKey,
    read_variable,
    read_expression
import Dates:
    DateTime,
    Hour
const IS = InfrastructureSystems

@testset "Test OptimizationProblemResults" begin
    base_power = 1.0
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
    var_key = VariableKey(IS.Optimization.MockVariable, IS.TestComponent)
    variable_values = Dict(var_key => DataFrame(["test" => 1:2]))
    dual_values = Dict()
    parameter_values = Dict()
    exp_key = ExpressionKey(IS.Optimization.MockExpression, IS.TestComponent)
    # Expression only 1 time-step
    expression_values = Dict(exp_key => DataFrame(["test2" => 1]))
    optimizer_stats = DataFrames.DataFrame()
    metadata = OptimizationContainerMetadata()
    # Test with StepRange
    opt_res1 = OptimizationProblemResults(
        1.0,
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
        1.0,
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
    # Check that variable has time series
    var_res = read_variable(opt_res1, var_key)
    @test size(var_res) == (2, 2)
    @test length(var_res[!, "DateTime"]) == 2
    # Check that expression only has a single column
    @test size(read_expression(opt_res2, exp_key)) == (1, 1)
end
