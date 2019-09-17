
@testset "Test components" begin
    data = SystemData()

    name = "component1"
    component = IS.TestComponent(name, 5)
    add_component!(data, component)

    component = get_component(IS.TestComponent, data, name)
    @test component.name == name

    components = get_components(IS.TestComponent, data)
    @test length(components) == 1

    i = 0
    for component in iterate_components(data)
        i += 1
    end
    @test i == 1

    remove_component!(data, collect(components)[1])
    components = get_components(IS.TestComponent, data)
    @test length(components) == 0

    add_component!(data, component)
    components = get_components_by_name(InfrastructureSystemsType, data, name)
    @test length(components) == 1
    @test components[1].name == name

    remove_components!(IS.TestComponent, data)
    components = get_components(IS.TestComponent, data)
    @test length(components) == 0
end

@testset "Test forecasts" begin
end
