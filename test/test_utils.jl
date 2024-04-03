@testset "Test utility functions" begin
    concrete_types = IS.get_all_concrete_subtypes(IS.InfrastructureSystemsComponent)
    @test length([x for x in concrete_types if isconcretetype(x)]) == length(concrete_types)
end

@testset "Test strip_module_name" begin
    @test IS.strip_module_name("PowerSystems.HydroDispatch") == "HydroDispatch"

    @test IS.strip_module_name(
        "InfrastructureSystems.SingleTimeSeries{PowerSystems.HydroDispatch}",
    ) == "SingleTimeSeries{PowerSystems.HydroDispatch}"

    @test IS.strip_module_name("SingleTimeSeries{PowerSystems.HydroDispatch}") ==
          "SingleTimeSeries{PowerSystems.HydroDispatch}"
end

@testset "Test exported names" begin
    @test IS.validate_exported_names(IS)
end

IS.@scoped_enum Fruit APPLE = 1 ORANGE = 2

@testset "Test scoped_enum" begin
    @test Fruit.APPLE isa Fruit
    @test Fruit.ORANGE isa Fruit
    @test sort([Fruit.ORANGE, Fruit.APPLE]) == [Fruit.APPLE, Fruit.ORANGE]

    @kwdef struct Foo
        fruit::Fruit
    end
    @test Foo(1) == Foo(Fruit.APPLE)

    @test IS.serialize(Fruit.APPLE) isa AbstractString
    @test IS.deserialize(Fruit, IS.serialize(Fruit.APPLE)) == Fruit.APPLE

    @test IS.deserialize_struct(Foo, IS.serialize_struct(Foo(Fruit.APPLE))) ==
          Foo(Fruit.APPLE)
end

@testset "Test undef component prints" begin
    v = Vector{IS.InfrastructureSystemsComponent}(undef, 3)
    @test sprint(show, v) ==
          "InfrastructureSystems.InfrastructureSystemsComponent[#undef, #undef, #undef]"
end

struct FakeTimeSeries <: InfrastructureSystems.TimeSeriesData end
Base.length(::FakeTimeSeries) = 42

@testset "Test TimeSeriesData printing" begin
    @test occursin(
        "FakeTimeSeries time_series (42)",
        sprint(show, MIME("text/plain"), FakeTimeSeries()),
    )
end
