import InfrastructureSystems.Optimization:
    OptimizationContainerMetadata,
    OptimizationProblemResults,
    VariableKey,
    ExpressionKey,
    MockVariable,
    MockExpression,
    read_variable,
    read_expression,
    convert_result_to_natural_units
import Dates:
    DateTime,
    Millisecond
const IS = InfrastructureSystems

@testset "Test OptimizationProblemResults" begin
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
    var_key = VariableKey(MockVariable, IS.TestComponent)
    variable_values = Dict(var_key => DataFrame(["test" => [1.0, 2.0]]))
    dual_values = Dict()
    parameter_values = Dict()
    exp_key = ExpressionKey(MockExpression, IS.TestComponent)
    # Expression only 1 time-step
    expression_values = Dict(exp_key => DataFrame(["test2" => 1.0]))
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
    # Check that variable has time series
    var_res = read_variable(opt_res1, var_key)
    @test size(var_res) == (2, 2)
    @test length(var_res[!, "DateTime"]) == 2
    @test [1.0, 2.0] == var_res[!, 2]
    convert_result_to_natural_units(::Type{<:MockVariable}) = true
    var_res = IS.Optimization.read_variable(opt_res1, var_key)
    @test var_res[!, 2] == [10.0, 20.0]
    # Check that expression only has a single column
    exp_res = read_expression(opt_res2, exp_key)
    @test size(exp_res) == (1, 1)
    @test exp_res[!, 1] == 1.0
    convert_result_to_natural_units(::Type{<:MockExpression}) = true
    exp_res = read_expression(opt_res2, exp_key)
    @test exp_res[!, 1] == 10.0
end
