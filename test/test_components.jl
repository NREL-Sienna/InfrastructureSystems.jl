
@testset "Test add_component" begin
    container = Components{Component}()

    component = TestComponent("component1", 5)
    add_component!(container, component)
    @test length(container.data) == 1
    @test length(container.data[TestComponent]) == 1

    @test_throws ArgumentError add_component!(container, component)

    struct BadComponent
        name::AbstractString
        val::Int
    end

    container = Components{Component}()
    component = BadComponent("component1", 5)
    @test_throws MethodError add_component!(container, component)
end

@testset "Test remove_component" begin
    container = Components{Component}()

    component = TestComponent("component1", 5)
    add_component!(container, component)
    components = get_components(TestComponent, container)
    @test length(components) == 1

    remove_component!(container, component)
    components = get_components(TestComponent, container)
    @test length(components) == 0
end

@testset "Test get_components" begin
    container = Components{Component}()

    # empty
    components = get_components(TestComponent, container)
    @test length(components) == 0

    component = TestComponent("component1", 5)
    add_component!(container, component)

    # by abstract type
    components = get_components(Component, container)
    @test length(components) == 1

    # by concrete type
    components = get_components(TestComponent, container)
    @test length(components) == 1

end

@testset "Test get_component" begin
    container = Components{Component}()

    component = TestComponent("component1", 5)
    add_component!(container, component)

    component = get_component(TestComponent, container, "component1")
    @test component.name == "component1"
    @test component.val == 5

    @test_throws ArgumentError get_component(Component, container, "component1")
end

@testset "Test get_components_by_name" begin
    container = Components{Component}()

    component = TestComponent("component1", 5)
    add_component!(container, component)

    components = get_components_by_name(Component, container, "component1")
    @test length(components) == 1
    @test component.name == "component1"
    @test component.val == 5
end

@testset "Test iterate_components" begin
    container = Components{Component}()
    component = TestComponent("component1", 5)
    add_component!(container, component)

    i = 0
    for component in iterate_components(container)
        i += 1
    end
    @test i == 1
end

@testset "Summarize components" begin
    container = Components{Component}()
    component = TestComponent("component1", 5)
    add_component!(container, component)
    summary(devnull, container)
end
