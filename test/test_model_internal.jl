import InfrastructureSystems.Optimization: ModelInternal
const IS = InfrastructureSystems
@testset "Test Model Internal" begin
    internal = ModelInternal(
        IS.Optimization.MockContainer(),
    )
    @test IS.Optimization.get_status(internal) == IS.Optimization.BuildStatus.EMPTY
    IS.Optimization.set_ic_model_container!(internal, IS.Optimization.MockContainer())
    @test isa(
        IS.Optimization.get_ic_model_container(internal),
        IS.Optimization.MockContainer,
    )
    IS.Optimization.add_recorder!(internal, :MockRecorder)
    @test IS.Optimization.get_recorders(internal)[1] == :MockRecorder
    IS.Optimization.set_status!(internal, IS.Optimization.BuildStatus.BUILT)
    @test IS.Optimization.get_status(internal) == IS.Optimization.BuildStatus.BUILT
    IS.Optimization.set_output_dir!(internal, mktempdir())
    log_config = IS.Optimization.configure_logging(internal, "test_log.log", "a")
    @test !isempty(log_config.loggers)
end
