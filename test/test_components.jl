
@testset "Test add_component" begin
    container = IS.Components(IS.InMemoryTimeSeriesStorage())

    component = IS.TestComponent("component1", 5)
    IS.add_component!(container, component)
    @test length(container.data) == 1
    @test length(container.data[IS.TestComponent]) == 1
    @test IS.get_num_components(container) == 1

    @test_throws ArgumentError IS.add_component!(container, component)

    struct BadComponent
        name::AbstractString
        val::Int
    end

    container = IS.Components(IS.InMemoryTimeSeriesStorage())
    component = BadComponent("component1", 5)
    @test_throws MethodError IS.add_component!(container, component)
end

@testset "Test clear_components" begin
    container = IS.Components(IS.InMemoryTimeSeriesStorage())

    component = IS.TestComponent("component1", 5)
    IS.add_component!(container, component)
    components = IS.get_components(IS.TestComponent, container)
    @test length(components) == 1

    IS.clear_components!(container)
    components = IS.get_components(IS.TestComponent, container)
    @test length(components) == 0
end

@testset "Test remove_component" begin
    container = IS.Components(IS.InMemoryTimeSeriesStorage())

    component = IS.TestComponent("component1", 5)
    IS.add_component!(container, component)
    components = IS.get_components(IS.TestComponent, container)
    @test length(components) == 1

    IS.remove_component!(container, component)
    components = IS.get_components(IS.TestComponent, container)
    @test length(components) == 0
end

@testset "Test remove_component by name" begin
    container = IS.Components(IS.InMemoryTimeSeriesStorage())

    name = "component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(container, component)
    components = IS.get_components(IS.TestComponent, container)
    @test length(components) == 1

    IS.remove_component!(IS.TestComponent, container, name)
    components = IS.get_components(IS.TestComponent, container)
    @test length(components) == 0

    @test_throws ArgumentError IS.remove_component!(IS.TestComponent, container, name)

    IS.add_component!(container, component)
    name2 = "component2"
    component2 = IS.TestComponent(name2, 6)
    IS.add_component!(container, component2)
    components = IS.get_components(IS.TestComponent, container)
    @test length(components) == 2

    IS.remove_component!(IS.TestComponent, container, name)
    components = IS.get_components(IS.TestComponent, container)
    @test length(components) == 1
    @test_throws ArgumentError IS.remove_component!(IS.TestComponent, container, name)
end

@testset "Test get_components" begin
    container = IS.Components(IS.InMemoryTimeSeriesStorage())

    # empty
    components = IS.get_components(IS.TestComponent, container)
    @test length(components) == 0

    component = IS.TestComponent("component1", 5)
    IS.add_component!(container, component)

    # by abstract type
    components = IS.get_components(IS.InfrastructureSystemsComponent, container)
    @test length(components) == 1

    # by concrete type
    components = IS.get_components(IS.TestComponent, container)
    @test length(components) == 1

    # by abstract type with filter_func
    components = IS.get_components(IS.InfrastructureSystemsComponent, container)
    @test length(components) == 1
    components = IS.get_components(
        x -> (IS.get_val(x) < 5),
        IS.InfrastructureSystemsComponent,
        container,
    )
    @test length(components) == 0
    components = IS.get_components(IS.InfrastructureSystemsComponent, container)
    @test length(components) == 1
    components = IS.get_components(
        x -> (IS.get_val(x) == 5),
        IS.InfrastructureSystemsComponent,
        container,
    )
    @test length(components) == 1

    # by concrete type
    components = IS.get_components(x -> (IS.get_val(x) < 5), IS.TestComponent, container)
    @test length(components) == 0
    components = IS.get_components(x -> (IS.get_val(x) == 5), IS.TestComponent, container)
    @test length(components) == 1
end

@testset "Test get_component" begin
    container = IS.Components(IS.InMemoryTimeSeriesStorage())

    component = IS.TestComponent("component1", 5)
    IS.add_component!(container, component)

    component = IS.get_component(IS.TestComponent, container, "component1")
    @test component.name == "component1"
    @test component.val == 5

    same_name_component = IS.AdditionalTestComponent("component1", 5)
    IS.add_component!(container, same_name_component)

    @test_throws ArgumentError IS.get_component(
        IS.InfrastructureSystemsComponent,
        container,
        "component1",
    )
end

@testset "Test empty get_component" begin
    container = IS.Components(IS.InMemoryTimeSeriesStorage())
    @test isempty(collect(IS.get_components(IS.TestComponent, container)))
end

@testset "Test get_components_by_name" begin
    container = IS.Components(IS.InMemoryTimeSeriesStorage())

    component = IS.TestComponent("component1", 5)
    IS.add_component!(container, component)

    components = IS.get_components_by_name(
        IS.InfrastructureSystemsComponent,
        container,
        "component1",
    )
    @test length(components) == 1
    @test component.name == "component1"
    @test component.val == 5
end

@testset "Test iterate_components" begin
    container = IS.Components(IS.InMemoryTimeSeriesStorage())
    component = IS.TestComponent("component1", 5)
    IS.add_component!(container, component)

    i = 0
    for component in IS.iterate_components(container)
        i += 1
    end
    @test i == 1
end

@testset "Test components serialization" begin
    container = IS.Components(IS.InMemoryTimeSeriesStorage())
    component = IS.TestComponent("component1", 5)
    IS.add_component!(container, component)
    data = IS.serialize(container)
    @test data isa Vector
    @test !isempty(data)
    @test data[1] isa Dict
end

@testset "Summarize components" begin
    container = IS.Components(IS.InMemoryTimeSeriesStorage())
    component = IS.TestComponent("component1", 5)
    IS.add_component!(container, component)
    summary(devnull, container)
end
