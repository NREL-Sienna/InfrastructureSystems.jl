
@testset "Test add_component" begin
    container = IS.Components()

    component = IS.TestComponent("component1", 5)
    IS.add_component!(container, component)
    @test length(container.data) == 1
    @test length(container.data[IS.TestComponent]) == 1

    @test_throws ArgumentError IS.add_component!(container, component)

    struct BadComponent
        name::AbstractString
        val::Int
    end

    container = IS.Components()
    component = BadComponent("component1", 5)
    @test_throws MethodError IS.add_component!(container, component)
end

@testset "Test remove_component" begin
    container = IS.Components()

    component = IS.TestComponent("component1", 5)
    IS.add_component!(container, component)
    components = IS.get_components(IS.TestComponent, container)
    @test length(components) == 1

    IS.remove_component!(container, component)
    components = IS.get_components(IS.TestComponent, container)
    @test length(components) == 0
end

@testset "Test IS.get_components" begin
    container = IS.Components()

    # empty
    components = IS.get_components(IS.TestComponent, container)
    @test length(components) == 0

    component = IS.TestComponent("component1", 5)
    IS.add_component!(container, component)

    # by abstract type
    components = IS.get_components(IS.InfrastructureSystemsType, container)
    @test length(components) == 1

    # by concrete type
    components = IS.get_components(IS.TestComponent, container)
    @test length(components) == 1

end

@testset "Test IS.get_component" begin
    container = IS.Components()

    component = IS.TestComponent("component1", 5)
    IS.add_component!(container, component)

    component = IS.get_component(IS.TestComponent, container, "component1")
    @test component.name == "component1"
    @test component.val == 5

    @test_throws ArgumentError IS.get_component(IS.InfrastructureSystemsType, container, "component1")
end

@testset "Test IS.get_components_by_name" begin
    container = IS.Components()

    component = IS.TestComponent("component1", 5)
    IS.add_component!(container, component)

    components = IS.get_components_by_name(IS.InfrastructureSystemsType, container, "component1")
    @test length(components) == 1
    @test component.name == "component1"
    @test component.val == 5
end

@testset "Test IS.iterate_components" begin
    container = IS.Components()
    component = IS.TestComponent("component1", 5)
    IS.add_component!(container, component)

    i = 0
    for component in IS.iterate_components(container)
        i += 1
    end
    @test i == 1
end

@testset "Summarize components" begin
    container = IS.Components()
    component = IS.TestComponent("component1", 5)
    IS.add_component!(container, component)
    summary(devnull, container)
end
