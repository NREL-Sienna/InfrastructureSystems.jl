
@testset "Test components" begin
    data = IS.SystemData()

    name = "component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(data, component)

    component = IS.get_component(IS.TestComponent, data, name)
    @test component.name == name

    components = IS.get_components(IS.TestComponent, data)
    @test length(components) == 1

    i = 0
    for component in IS.iterate_components(data)
        i += 1
    end
    @test i == 1

    io = IOBuffer()
    show(io, "text/plain", components)
    output = String(take!(io))
    expected = "TestComponent: $i"
    @test occursin(expected, output)

    IS.remove_component!(data, collect(components)[1])
    components = IS.get_components(IS.TestComponent, data)
    @test length(components) == 0

    IS.add_component!(data, component)
    components = IS.get_components_by_name(IS.InfrastructureSystemsComponent, data, name)
    @test length(components) == 1
    @test components[1].name == name

    IS.remove_components!(IS.TestComponent, data)
    components = IS.get_components(IS.TestComponent, data)
    @test length(components) == 0

    @test_throws ArgumentError IS.remove_components!(IS.TestComponent, data)
end

@testset "Test masked components" begin
    data = IS.SystemData()
    initial_time = Dates.DateTime("2020-09-01")
    resolution = Dates.Hour(1)
    ta = TimeSeries.TimeArray(range(initial_time; length = 24, step = resolution), ones(24))
    ts = IS.SingleTimeSeries(data = ta, name = "test")

    for i in 1:3
        name = "component_$(i)"
        component = IS.TestComponent(name, 5)
        IS.add_component!(data, component)
        IS.add_time_series!(data, component, ts)
    end

    component = IS.get_component(IS.TestComponent, data, "component_2")
    @test component isa IS.InfrastructureSystemsComponent
    IS.mask_component!(data, component)
    @test IS.get_component(IS.TestComponent, data, "component_2") === nothing
    @test IS.get_masked_component(IS.TestComponent, data, "component_2") isa
          IS.TestComponent
    @test collect(IS.get_masked_components(IS.TestComponent, data)) == [component]
    @test IS.get_masked_components_by_name(
        IS.InfrastructureSystemsComponent,
        data,
        "component_2",
    ) == [component]
    @test IS.get_time_series(IS.SingleTimeSeries, component, "test") isa IS.SingleTimeSeries
    @test IS.is_attached(component, data.masked_components)

    # This needs to return time series for masked components.
    @test length(collect(IS.get_time_series_multiple(data, type = IS.SingleTimeSeries))) ==
          3
end
