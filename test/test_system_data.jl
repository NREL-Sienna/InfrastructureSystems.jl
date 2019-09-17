
@testset "Test components" begin
    data = IS.SystemData()

    name = "component1"
    component = TestComponent(name, 5)
    IS.add_component!(data, component)

    component = IS.get_component(TestComponent, data, name)
    @test component.name == name

    components = IS.get_components(TestComponent, data)
    @test length(components) == 1

    i = 0
    for component in IS.iterate_components(data)
        i += 1
    end
    @test i == 1

    IS.remove_component!(data, collect(components)[1])
    components = IS.get_components(TestComponent, data)
    @test length(components) == 0

    IS.add_component!(data, component)
    components = IS.get_components_by_name(IS.InfrastructureSystemsType, data, name)
    @test length(components) == 1
    @test components[1].name == name

    IS.remove_components!(TestComponent, data)
    components = IS.get_components(TestComponent, data)
    @test length(components) == 0
end

@testset "Test forecasts" begin
end
