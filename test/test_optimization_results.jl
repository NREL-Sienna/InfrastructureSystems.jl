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
            DateTime("2024-01-01T03:00:00"),
        )
    timestamp_vec = collect(timestamp_range)
    data = IS.SystemData()
    uuid = IS.make_uuid()
    aux_variable_values = Dict()
    @test !IS.Optimization.convert_result_to_natural_units(MockVariable)
    @test IS.Optimization.convert_result_to_natural_units(MockVariable2)
    var_key1 = VariableKey(MockVariable, IS.TestComponent)
    var_key2 = VariableKey(MockVariable2, IS.TestComponent)
    vals = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
    variable_values = Dict(
        var_key1 => DataFrame(
            "time_index" => [1, 2, 3, 4, 1, 2, 3, 4],
            "name" => ["c1", "c1", "c1", "c1", "c2", "c2", "c2", "c2"],
            "value" => vals,
        ),
        var_key2 => DataFrame(
            "time_index" => [1, 2, 3, 4, 1, 2, 3, 4],
            "name" => ["c1", "c1", "c1", "c1", "c2", "c2", "c2", "c2"],
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
            "time_index" => [1, 2, 3, 4, 1, 2, 3, 4],
            "name" => ["c1", "c1", "c1", "c1", "c2", "c2", "c2", "c2"],
            "value" => vals,
        ),
        exp_key2 => DataFrame(
            "time_index" => [1, 2, 3, 4, 1, 2, 3, 4],
            "custom_name" => ["c1", "c1", "c1", "c1", "c2", "c2", "c2", "c2"],
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
    opt_res3 = OptimizationProblemResults(
        base_power,
        [timestamp_vec[1]],
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
    @test @rsubset(var_res, :name == "c1")[!, :value] == [1.0, 2.0, 3.0, 4.0]
    @test @rsubset(var_res, :name == "c2")[!, :value] == [5.0, 6.0, 7.0, 8.0]

    var_res = read_variable(opt_res1, var_key2)
    @test @rsubset(var_res, :name == "c1")[!, :value] == [10.0, 20.0, 30.0, 40.0]
    @test @rsubset(var_res, :name == "c2")[!, :value] == [50.0, 60.0, 70.0, 80.0]

    var_res2 = read_variable(
        opt_res1,
        var_key1;
        start_time = DateTime("2024-01-01T01:00:00"),
        len = 2,
    )
    @test @rsubset(var_res2, :name == "c1")[!, :value] == [2.0, 3.0]
    @test @rsubset(var_res2, :name == "c2")[!, :value] == [6.0, 7.0]

    var_res2 = read_variable(
        opt_res1,
        var_key2;
        start_time = DateTime("2024-01-01T01:00:00"),
        len = 2,
    )
    @test @rsubset(var_res2, :name == "c1")[!, :value] == [20.0, 30.0]
    @test @rsubset(var_res2, :name == "c2")[!, :value] == [60.0, 70.0]

    var_res = read_variable(opt_res1, var_key2; table_format = IS.TableFormat.WIDE)
    @test var_res[!, :c1] == [10.0, 20.0, 30.0, 40.0]
    @test var_res[!, :c2] == [50.0, 60.0, 70.0, 80.0]

    exp_res = read_expression(opt_res2, exp_key1)
    @test @rsubset(exp_res, :name == "c1")[!, :value] == [1.0, 2.0, 3.0, 4.0]
    @test @rsubset(exp_res, :name == "c2")[!, :value] == [5.0, 6.0, 7.0, 8.0]
    exp_res = read_expression(opt_res2, exp_key2)
    @test @rsubset(exp_res, :custom_name == "c1")[!, :value] == [10.0, 20.0, 30.0, 40.0]
    @test @rsubset(exp_res, :custom_name == "c2")[!, :value] == [50.0, 60.0, 70.0, 80.0]

    @test IS.Optimization.get_resolution(opt_res1) == Millisecond(3600000)
    @test IS.Optimization.get_resolution(opt_res2) == Millisecond(3600000)
    @show IS.Optimization.get_resolution(opt_res3)
    @test isnothing(IS.Optimization.get_resolution(opt_res3))
end

@testset "Test OptimizationProblemResults 3d long format" begin
    timestamps = StepRange(
        DateTime("2024-01-01T00:00:00"),
        Millisecond(3600000),
        DateTime("2024-01-01T01:00:00"),
    )
    data = IS.SystemData()
    aux_variable_values = Dict()
    var_key = VariableKey(MockVariable, IS.TestComponent)
    vals = [1.0, 2.0, 3.0, 4.0]
    variable_values = Dict(
        var_key => DataFrame(
            "time_index" => [1, 2, 1, 2],
            "name" => ["c1", "c2", "c1", "c2"],
            "name2" => ["c3", "c4", "c3", "c4"],
            "value" => vals,
        ),
    )
    optimizer_stats = DataFrames.DataFrame()
    res = OptimizationProblemResults(
        100.0,
        timestamps,
        data,
        IS.make_uuid(),
        Dict(),
        variable_values,
        Dict(),
        Dict(),
        Dict(),
        optimizer_stats,
        OptimizationContainerMetadata(),
        "test_model",
        mktempdir(),
        mktempdir(),
    )

    var_res = read_variable(res, var_key)
    @test @rsubset(var_res, :name == "c1" && :name2 == "c3")[!, :value] == [1.0, 3.0]
    @test @rsubset(var_res, :name == "c2" && :name2 == "c4")[!, :value] == [2.0, 4.0]
end

@testset "Test OptimizationProblemResults _process_timestamps" begin
    time_ids = [1, 2, 3, 4]
    timestamps = [
        DateTime("2024-01-01T00:00:00"),
        DateTime("2024-01-01T01:00:00"),
        DateTime("2024-01-01T02:00:00"),
        DateTime("2024-01-01T03:00:00"),
    ]
    data = IS.SystemData()
    var_key = VariableKey(MockVariable, IS.TestComponent)
    vals = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
    variable_values = Dict(
        var_key => DataFrame(
            "time_index" => [1, 2, 3, 4, 1, 2, 3, 4],
            "name" => ["c1", "c1", "c1", "c1", "c2", "c2", "c2", "c2"],
            "value" => vals,
        ),
    )
    optimizer_stats = DataFrames.DataFrame()
    metadata = OptimizationContainerMetadata()
    opt_res = OptimizationProblemResults(
        100.0,
        timestamps,
        data,
        IS.make_uuid(),
        Dict(),
        variable_values,
        Dict(),
        Dict(),
        Dict(),
        optimizer_stats,
        metadata,
        "DecisionModel",
        mktempdir(),
        mktempdir(),
    )
    @test IS.Optimization._process_timestamps(opt_res, nothing, nothing) ==
          (time_ids, timestamps)
    @test IS.Optimization._process_timestamps(opt_res, timestamps[2], nothing) ==
          (time_ids[2:end], timestamps[2:end])
    @test IS.Optimization._process_timestamps(opt_res, timestamps[4], nothing) ==
          ([time_ids[4]], [timestamps[4]])
    @test IS.Optimization._process_timestamps(opt_res, nothing, 3) ==
          (time_ids[1:3], timestamps[1:3])
    @test IS.Optimization._process_timestamps(opt_res, timestamps[2], 2) ==
          (time_ids[2:3], timestamps[2:3])

    @test_throws IS.InvalidValue IS.Optimization._process_timestamps(
        opt_res,
        timestamps[1] - Hour(1),
        nothing,
    )
    @test_throws IS.InvalidValue IS.Optimization._process_timestamps(
        opt_res,
        timestamps[4] + Hour(1),
        nothing,
    )
    @test_throws IS.InvalidValue IS.Optimization._process_timestamps(opt_res, nothing, -1)
    @test_throws IS.InvalidValue IS.Optimization._process_timestamps(opt_res, nothing, 10)
    @test_throws IS.InvalidValue IS.Optimization._process_timestamps(
        opt_res,
        timestamps[2],
        10,
    )
end

@testset "Test OptimizationProblemResults read_duals" begin
    base_power = 100.0
    timestamps = [
        DateTime("2024-01-01T00:00:00"),
        DateTime("2024-01-01T01:00:00"),
    ]
    data = IS.SystemData()
    uuid = IS.make_uuid()

    dual_key = IS.Optimization.ConstraintKey(MockConstraint, IS.TestComponent)
    dual_values = Dict(
        dual_key => DataFrame(
            "time_index" => [1, 2, 1, 2],
            "name" => ["c1", "c1", "c2", "c2"],
            "value" => [10.0, 20.0, 30.0, 40.0],
        ),
    )

    res = OptimizationProblemResults(
        base_power,
        timestamps,
        data,
        uuid,
        Dict(),
        Dict(),
        dual_values,
        Dict(),
        Dict(),
        DataFrames.DataFrame(),
        OptimizationContainerMetadata(),
        "test_model",
        mktempdir(),
        mktempdir(),
    )

    # Test read_dual
    dual_res = IS.Optimization.read_dual(res, dual_key)
    @test @rsubset(dual_res, :name == "c1")[!, :value] == [10.0, 20.0]
    @test @rsubset(dual_res, :name == "c2")[!, :value] == [30.0, 40.0]

    # Test list_dual_keys
    @test dual_key in IS.Optimization.list_dual_keys(res)
end

@testset "Test OptimizationProblemResults read_parameters" begin
    base_power = 100.0
    timestamps = [
        DateTime("2024-01-01T00:00:00"),
        DateTime("2024-01-01T01:00:00"),
    ]
    data = IS.SystemData()
    uuid = IS.make_uuid()

    param_key = IS.Optimization.ParameterKey(MockParameter, IS.TestComponent)
    parameter_values = Dict(
        param_key => DataFrame(
            "time_index" => [1, 2, 1, 2],
            "name" => ["c1", "c1", "c2", "c2"],
            "value" => [0.5, 0.6, 0.7, 0.8],
        ),
    )

    res = OptimizationProblemResults(
        base_power,
        timestamps,
        data,
        uuid,
        Dict(),
        Dict(),
        Dict(),
        parameter_values,
        Dict(),
        DataFrames.DataFrame(),
        OptimizationContainerMetadata(),
        "test_model",
        mktempdir(),
        mktempdir(),
    )

    # Test read_parameter
    param_res = IS.Optimization.read_parameter(res, param_key)
    @test @rsubset(param_res, :name == "c1")[!, :value] == [0.5, 0.6]
    @test @rsubset(param_res, :name == "c2")[!, :value] == [0.7, 0.8]

    # Test list_parameter_keys
    @test param_key in IS.Optimization.list_parameter_keys(res)
end

@testset "Test OptimizationProblemResults read_aux_variables" begin
    base_power = 100.0
    timestamps = [
        DateTime("2024-01-01T00:00:00"),
        DateTime("2024-01-01T01:00:00"),
    ]
    data = IS.SystemData()
    uuid = IS.make_uuid()

    aux_key = IS.Optimization.AuxVarKey(MockAuxVariable, IS.TestComponent)
    aux_variable_values = Dict(
        aux_key => DataFrame(
            "time_index" => [1, 2, 1, 2],
            "name" => ["c1", "c1", "c2", "c2"],
            "value" => [100.0, 200.0, 300.0, 400.0],
        ),
    )

    res = OptimizationProblemResults(
        base_power,
        timestamps,
        data,
        uuid,
        aux_variable_values,
        Dict(),
        Dict(),
        Dict(),
        Dict(),
        DataFrames.DataFrame(),
        OptimizationContainerMetadata(),
        "test_model",
        mktempdir(),
        mktempdir(),
    )

    # Test read_aux_variable
    aux_res = IS.Optimization.read_aux_variable(res, aux_key)
    @test @rsubset(aux_res, :name == "c1")[!, :value] == [100.0, 200.0]
    @test @rsubset(aux_res, :name == "c2")[!, :value] == [300.0, 400.0]

    # Test list_aux_variable_keys
    @test aux_key in IS.Optimization.list_aux_variable_keys(res)
end

@testset "Test OptimizationProblemResults getters" begin
    base_power = 150.0
    timestamps = [DateTime("2024-01-01T00:00:00")]
    data = IS.SystemData()
    uuid = IS.make_uuid()

    res = OptimizationProblemResults(
        base_power,
        timestamps,
        data,
        uuid,
        Dict(),
        Dict(),
        Dict(),
        Dict(),
        Dict(),
        DataFrames.DataFrame(:objective_value => [1234.5]),
        OptimizationContainerMetadata(),
        "TestModel",
        "/test/results",
        "/test/output",
    )

    @test IS.Optimization.get_model_base_power(res) == base_power
    @test IS.Optimization.get_timestamps(res) == timestamps
    @test IS.Optimization.get_source_data(res) === data
    @test IS.Optimization.get_source_data_uuid(res) == uuid
    @test IS.Optimization.get_results_dir(res) == "/test/results"
    @test IS.Optimization.get_output_dir(res) == "/test/output"
    @test IS.Optimization.get_forecast_horizon(res) == 1
    @test IS.Optimization.get_objective_value(res) == 1234.5
end

@testset "Test OptimizationProblemResults list functions" begin
    base_power = 100.0
    timestamps = [DateTime("2024-01-01T00:00:00")]
    data = IS.SystemData()
    uuid = IS.make_uuid()

    var_key = VariableKey(MockVariable, IS.TestComponent)
    aux_key = IS.Optimization.AuxVarKey(MockAuxVariable, IS.TestComponent)
    dual_key = IS.Optimization.ConstraintKey(MockConstraint, IS.TestComponent)
    param_key = IS.Optimization.ParameterKey(MockParameter, IS.TestComponent)
    expr_key = ExpressionKey(MockExpression, IS.TestComponent)

    res = OptimizationProblemResults(
        base_power,
        timestamps,
        data,
        uuid,
        Dict(aux_key => DataFrame()),
        Dict(var_key => DataFrame()),
        Dict(dual_key => DataFrame()),
        Dict(param_key => DataFrame()),
        Dict(expr_key => DataFrame()),
        DataFrames.DataFrame(),
        OptimizationContainerMetadata(),
        "test_model",
        mktempdir(),
        mktempdir(),
    )

    # Test list functions
    @test var_key in IS.Optimization.list_variable_keys(res)
    @test aux_key in IS.Optimization.list_aux_variable_keys(res)
    @test dual_key in IS.Optimization.list_dual_keys(res)
    @test param_key in IS.Optimization.list_parameter_keys(res)
    @test expr_key in IS.Optimization.list_expression_keys(res)

    # Test name encoding functions
    var_names = IS.Optimization.list_variable_names(res)
    @test length(var_names) == 1
    @test isa(var_names[1], String)

    aux_names = IS.Optimization.list_aux_variable_names(res)
    @test length(aux_names) == 1

    dual_names = IS.Optimization.list_dual_names(res)
    @test length(dual_names) == 1

    param_names = IS.Optimization.list_parameter_names(res)
    @test length(param_names) == 1

    expr_names = IS.Optimization.list_expression_names(res)
    @test length(expr_names) == 1
end

@testset "Test OptimizationProblemResults serialize and deserialize" begin
    base_power = 100.0
    timestamps = [DateTime("2024-01-01T00:00:00")]
    data = IS.SystemData()
    uuid = IS.make_uuid()

    var_key = VariableKey(MockVariable, IS.TestComponent)
    variable_values = Dict(
        var_key => DataFrame(
            "time_index" => [1],
            "name" => ["c1"],
            "value" => [42.0],
        ),
    )

    res = OptimizationProblemResults(
        base_power,
        timestamps,
        data,
        uuid,
        Dict(),
        variable_values,
        Dict(),
        Dict(),
        Dict(),
        DataFrames.DataFrame(:objective_value => [100.0]),
        OptimizationContainerMetadata(),
        "test_model",
        mktempdir(),
        mktempdir(),
    )

    # Serialize
    temp_dir = mktempdir()
    IS.Optimization.serialize_results(res, temp_dir)

    # Deserialize
    res2 = OptimizationProblemResults(temp_dir)

    # Verify data is preserved
    @test IS.Optimization.get_model_base_power(res2) == base_power
    @test IS.Optimization.get_timestamps(res2) == timestamps
    @test IS.Optimization.get_source_data_uuid(res2) == uuid
    @test IS.Optimization.get_objective_value(res2) == 100.0

    # Source data should be nothing after deserialization
    @test isnothing(IS.Optimization.get_source_data(res2))
end

@testset "Test OptimizationProblemResults set_source_data!" begin
    base_power = 100.0
    timestamps = [DateTime("2024-01-01T00:00:00")]
    data = IS.SystemData()
    uuid = IS.make_uuid()

    res = OptimizationProblemResults(
        base_power,
        timestamps,
        nothing,  # No source data initially
        uuid,
        Dict(),
        Dict(),
        Dict(),
        Dict(),
        Dict(),
        DataFrames.DataFrame(),
        OptimizationContainerMetadata(),
        "test_model",
        mktempdir(),
        mktempdir(),
    )

    # Set source data with matching UUID
    IS.Optimization.set_source_data!(res, data)
    @test IS.Optimization.get_source_data(res) === data

    # Try to set source data with mismatched UUID
    data2 = IS.SystemData()
    @test_throws IS.InvalidValue IS.Optimization.set_source_data!(res, data2)
end
