
@testset "Test utility functions" begin
    concrete_types = IS.get_all_concrete_subtypes(IS.InfrastructureSystemsType)
    @test length([x for x in concrete_types if isconcretetype(x)]) == length(concrete_types)
end

@testset "Test strip_module_name" begin
    @test IS.strip_module_name("PowerSystems.HydroDispatch") == "HydroDispatch"

    @test IS.strip_module_name(
        "InfrastructureSystems.Deterministic{PowerSystems.HydroDispatch}") ==
        "Deterministic{PowerSystems.HydroDispatch}"
end

@testset "Test exported names" begin
    @test IS.validate_exported_names(IS)
end
