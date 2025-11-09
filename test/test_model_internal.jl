import InfrastructureSystems.Optimization:
    ModelInternal,
    ModelBuildStatus,
    get_container,
    get_recorders,
    get_store_params,
    get_status,
    get_execution_count,
    get_executions,
    get_initial_conditions_model_container,
    get_optimization_container,
    get_output_dir,
    get_time_series_cache,
    get_console_level,
    get_file_level,
    get_ext,
    get_base_conversion,
    set_container!,
    set_store_params!,
    set_console_level!,
    set_file_level!,
    set_executions!,
    set_execution_count!,
    set_initial_conditions_model_container!,
    set_status!,
    set_output_dir!,
    add_recorder!,
    configure_logging
import Logging

const IS = InfrastructureSystems

@testset "Test Model Internal construction" begin
    container = MockContainer()
    internal = ModelInternal(container)

    # Test default values
    @test get_container(internal) === container
    @test get_optimization_container(internal) === container
    @test get_status(internal) == ModelBuildStatus.EMPTY
    @test get_executions(internal) == 1
    @test get_execution_count(internal) == 0
    @test isnothing(get_output_dir(internal))
    @test isempty(get_recorders(internal))
    @test isnothing(get_store_params(internal))
    @test isnothing(get_initial_conditions_model_container(internal))
    @test isempty(get_time_series_cache(internal))

    # Test with custom ext
    custom_ext = Dict("key" => "value")
    internal2 = ModelInternal(container; ext = custom_ext)
    @test get_ext(internal2) == custom_ext

    # Test with custom recorders
    custom_recorders = [:recorder1, :recorder2]
    internal3 = ModelInternal(container; recorders = custom_recorders)
    @test get_recorders(internal3) == custom_recorders
end

@testset "Test Model Internal getters and setters" begin
    container = MockContainer()
    internal = ModelInternal(container)

    # Test execution count
    set_execution_count!(internal, 5)
    @test get_execution_count(internal) == 5

    # Test executions
    set_executions!(internal, 10)
    @test get_executions(internal) == 10

    # Test status - all enum values
    set_status!(internal, ModelBuildStatus.BUILT)
    @test get_status(internal) == ModelBuildStatus.BUILT

    set_status!(internal, ModelBuildStatus.FAILED)
    @test get_status(internal) == ModelBuildStatus.FAILED

    set_status!(internal, ModelBuildStatus.IN_PROGRESS)
    @test get_status(internal) == ModelBuildStatus.IN_PROGRESS

    set_status!(internal, ModelBuildStatus.EMPTY)
    @test get_status(internal) == ModelBuildStatus.EMPTY

    # Test output_dir
    test_dir = mktempdir()
    set_output_dir!(internal, test_dir)
    @test get_output_dir(internal) == test_dir

    # Test console and file levels
    set_console_level!(internal, Logging.Info)
    @test get_console_level(internal) == Logging.Info

    set_file_level!(internal, Logging.Debug)
    @test get_file_level(internal) == Logging.Debug

    set_console_level!(internal, Logging.Error)
    @test get_console_level(internal) == Logging.Error

    set_file_level!(internal, Logging.Warn)
    @test get_file_level(internal) == Logging.Warn

    # Test store_params
    store_params = MockStoreParams(100)
    set_store_params!(internal, store_params)
    @test get_store_params(internal) === store_params

    # Test container
    new_container = MockContainer()
    set_container!(internal, new_container)
    @test get_container(internal) === new_container

    # Test initial_conditions_model_container
    ic_container = MockContainer()
    set_initial_conditions_model_container!(internal, ic_container)
    @test get_initial_conditions_model_container(internal) === ic_container

    # Test setting to nothing
    set_initial_conditions_model_container!(internal, nothing)
    @test isnothing(get_initial_conditions_model_container(internal))
end

@testset "Test Model Internal recorders" begin
    container = MockContainer()
    internal = ModelInternal(container)

    @test isempty(get_recorders(internal))

    add_recorder!(internal, :recorder1)
    @test get_recorders(internal) == [:recorder1]

    add_recorder!(internal, :recorder2)
    @test get_recorders(internal) == [:recorder1, :recorder2]

    add_recorder!(internal, :recorder3)
    @test get_recorders(internal) == [:recorder1, :recorder2, :recorder3]
end

@testset "Test Model Internal configure_logging" begin
    container = MockContainer()
    internal = ModelInternal(container)

    test_dir = mktempdir()
    set_output_dir!(internal, test_dir)

    # Test with write mode
    logger = configure_logging(internal, "test.log", "w")
    @test logger !== nothing
    @test !isempty(logger.loggers)
    @test isfile(joinpath(test_dir, "test.log"))

    # Test with append mode
    logger2 = configure_logging(internal, "test2.log", "a")
    @test logger2 !== nothing
    @test isfile(joinpath(test_dir, "test2.log"))
end

@testset "Test Model Internal time_series_cache" begin
    container = MockContainer()
    internal = ModelInternal(container)

    cache = get_time_series_cache(internal)
    @test isa(cache, Dict)
    @test isempty(cache)
end

@testset "Test Model Internal base_conversion" begin
    container = MockContainer()
    internal = ModelInternal(container)

    # Test default value
    @test get_base_conversion(internal) == true
end
