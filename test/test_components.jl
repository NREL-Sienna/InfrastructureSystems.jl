
@testset "Test add_component" begin
    container = Components{BaseComponent}()

    component = Component("component1", 5)
    add_component!(container, component)
    @test length(container._store) == 1
    @test length(container._store[Component]) == 1

    @test_throws InvalidParameter add_component!(container, component)

    struct BadComponent
        name::AbstractString
        val::Int
    end

    container = Components{BaseComponent}()
    component = BadComponent("component1", 5)
    @test_throws MethodError add_component!(container, component)
end

@testset "Test remove_component" begin
    container = Components{BaseComponent}()

    component = Component("component1", 5)
    add_component!(container, component)
    components = get_components(Component, container)
    @test length(components) == 1

    remove_component!(container, component)
    components = get_components(Component, container)
    @test length(components) == 0
end

@testset "Test get_components" begin
    container = Components{BaseComponent}()

    # empty
    components = get_components(BaseComponent, container)
    @test length(components) == 0

    component = Component("component1", 5)
    add_component!(container, component)

    # by abstract type
    components = get_components(BaseComponent, container)
    @test length(components) == 1

    # by concrete type
    components = get_components(Component, container)
    @test length(components) == 1

end

@testset "Test get_component" begin
    container = Components{BaseComponent}()

    component = Component("component1", 5)
    add_component!(container, component)

    component = get_component(Component, container, "component1")
    @test component.name == "component1"
    @test component.val == 5

    @test_throws InvalidParameter get_component(BaseComponent, container, "component1")
end

@testset "Test get_components_by_name" begin
    container = Components{BaseComponent}()

    component = Component("component1", 5)
    add_component!(container, component)

    components = get_components_by_name(BaseComponent, container, "component1")
    @test length(components) == 1
    @test component.name == "component1"
    @test component.val == 5
end

@testset "Test iterate_components" begin
    container = Components{BaseComponent}()
    component = Component("component1", 5)
    add_component!(container, component)

    i = 0
    for component in iterate_components(container)
        i += 1
    end
    @test i == 1
end

@testset "Summarize components" begin
    container = Components{BaseComponent}()
    component = Component("component1", 5)
    add_component!(container, component)
    summary(devnull, container)
end
