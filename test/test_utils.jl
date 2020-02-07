
@testset "Test utility functions" begin
    concrete_types = IS.get_all_concrete_subtypes(IS.InfrastructureSystemsType)
    @test length([x for x in concrete_types if isconcretetype(x)]) == length(concrete_types)
end

@testset "Test strip_module_name" begin
    @test IS.strip_module_name("PowerSystems.HydroDispatch") == "HydroDispatch"

    @test IS.strip_module_name("InfrastructureSystems.Deterministic{PowerSystems.HydroDispatch}") ==
          "Deterministic{PowerSystems.HydroDispatch}"

    @test IS.strip_module_name("Deterministic{PowerSystems.HydroDispatch}") ==
          "Deterministic{PowerSystems.HydroDispatch}"
end

@testset "Test strip_parametric_type" begin
    @test IS.strip_parametric_type("Deterministic{PowerSystems.HydroDispatch}") ==
          "Deterministic"

    @test IS.strip_parametric_type("InfrastructureSystems.Deterministic{PowerSystems.HydroDispatch}") ==
          "InfrastructureSystems.Deterministic"
end

@testset "Test serialization utility functions" begin
    text = "SomeType{ParameterType1, ParameterType2}"
    type_str, parameters = IS.separate_type_and_parameter_types(text)
    @test type_str == "SomeType"
    @test parameters == ["ParameterType1", "ParameterType2"]

    text = "SomeType"
    type_str, parameters = IS.separate_type_and_parameter_types(text)
    @test type_str == "SomeType"
    @test parameters == []
end

@testset "Test exported names" begin
    @test IS.validate_exported_names(IS)
end

IS.@scoped_enum Fruit begin
    APPLE
    ORANGE
end

@testset "Test scoped_enum" begin
    @test Fruits.APPLE isa Fruits.Fruit
    @test Fruits.ORANGE isa Fruits.Fruit
end
