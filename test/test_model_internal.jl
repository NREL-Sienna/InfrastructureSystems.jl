import InfrastructureSystems.Optimization: ModelInternal
import InfrastructureSystems as IS
@testset "Test Model Internal" begin
    internal = ModelInternal(
        MockContainer(),
    )
    @test IS.Optimization.get_status(internal) == IS.Optimization.ModelBuildStatus.EMPTY
    IS.Optimization.set_initial_conditions_model_container!(
        internal,
        MockContainer(),
    )
    @test isa(
        IS.Optimization.get_initial_conditions_model_container(internal),
        MockContainer,
    )
    IS.Optimization.add_recorder!(internal, :MockRecorder)
    @test IS.Optimization.get_recorders(internal)[1] == :MockRecorder
    IS.Optimization.set_status!(internal, IS.Optimization.ModelBuildStatus.BUILT)
    @test IS.Optimization.get_status(internal) == IS.Optimization.ModelBuildStatus.BUILT
    IS.Optimization.set_output_dir!(internal, mktempdir())
    log_config = IS.Optimization.configure_logging(internal, "test_log.log", "a")
    @test !isempty(log_config.loggers)
end
