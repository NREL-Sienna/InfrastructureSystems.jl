
@testset "Test components" begin
    data = SystemData{Component}()

    name = "component1"
    component = TestComponent(name, 5)
    add_component!(data, component)

    component = get_component(TestComponent, data, name)
    @test get_name(component) == name

    components = get_components(TestComponent, data)
    @test length(components) == 1

    i = 0
    for component in iterate_components(data)
        i += 1
    end
    @test i == 1

    remove_component!(data, collect(components)[1])
    components = get_components(TestComponent, data)
    @test length(components) == 0

    add_component!(data, component)
    components = get_components_by_name(Component, data, name)
    @test length(components) == 1
    @test get_name(components[1]) == name

    remove_components!(TestComponent, data)
    components = get_components(TestComponent, data)
    @test length(components) == 0
end

@testset "Test forecasts" begin
end
