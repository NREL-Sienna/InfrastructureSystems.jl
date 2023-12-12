@testset "Test add_supplemental_attribute" begin
    container = IS.SupplementalAttributes(IS.InMemoryTimeSeriesStorage())
    geo_supplemental_attribute = IS.GeographicInfo()
    component = IS.TestComponent("component1", 5)
    IS.add_supplemental_attribute!(container, component, geo_supplemental_attribute)
    @test length(container.data) == 1
    @test length(container.data[IS.GeographicInfo]) == 1
    @test IS.get_num_supplemental_attributes(container) == 1
    @test_throws ArgumentError IS.add_supplemental_attribute!(
        container,
        component,
        geo_supplemental_attribute,
    )

    container = IS.SupplementalAttributes(IS.InMemoryTimeSeriesStorage())
    geo_supplemental_attribute = IS.GeographicInfo()
    @test_throws ArgumentError IS._add_supplemental_attribute!(
        container,
        geo_supplemental_attribute,
    )
end

@testset "Test clear_supplemental_attributes" begin
    container = IS.SupplementalAttributes(IS.InMemoryTimeSeriesStorage())
    geo_supplemental_attribute = IS.GeographicInfo()
    component = IS.TestComponent("component1", 5)
    IS.add_supplemental_attribute!(container, component, geo_supplemental_attribute)
    @test IS.get_num_supplemental_attributes(container) == 1

    IS.clear_supplemental_attributes!(component)
    @test isempty(IS.get_components_uuids(geo_supplemental_attribute))
    IS.clear_supplemental_attributes!(container)
    supplemental_attributes =
        IS.get_supplemental_attributes(IS.GeographicInfo, container)
    @test length(supplemental_attributes) == 0
end

@testset "Test remove_supplemental_attribute" begin
    container = IS.SupplementalAttributes(IS.InMemoryTimeSeriesStorage())
    geo_supplemental_attribute = IS.GeographicInfo()
    component = IS.TestComponent("component1", 5)
    IS.add_supplemental_attribute!(container, component, geo_supplemental_attribute)
    @test IS.get_num_supplemental_attributes(container) == 1

    IS.remove_supplemental_attribute!(component, geo_supplemental_attribute)
    @test isempty(IS.get_supplemental_attributes_container(component))
    @test isempty(IS.get_components_uuids(geo_supplemental_attribute))
end

@testset "Test iterate_SupplementalAttributes" begin
    container = IS.SupplementalAttributes(IS.InMemoryTimeSeriesStorage())
    geo_supplemental_attribute = IS.GeographicInfo()
    component = IS.TestComponent("component1", 5)
    IS.add_supplemental_attribute!(container, component, geo_supplemental_attribute)

    i = 0
    for component in IS.iterate_supplemental_attributes(container)
        i += 1
    end
    @test i == 1
end

@testset "Summarize SupplementalAttributes" begin
    container = IS.SupplementalAttributes(IS.InMemoryTimeSeriesStorage())
    geo_supplemental_attribute = IS.GeographicInfo()
    component = IS.TestComponent("component1", 5)
    IS.add_supplemental_attribute!(container, component, geo_supplemental_attribute)
    summary(devnull, container)
end

@testset "Test supplemental_attributes serialization" begin
    container = IS.SupplementalAttributes(IS.InMemoryTimeSeriesStorage())
    geo_supplemental_attribute = IS.GeographicInfo()
    component = IS.TestComponent("component1", 5)
    IS.add_supplemental_attribute!(container, component, geo_supplemental_attribute)
    data = IS.serialize(container)
    @test data isa Vector
    @test !isempty(data)
    @test data[1] isa Dict
end

@testset "Add time series to supplemental_attribute" begin
    data = IS.SystemData()
    initial_time = Dates.DateTime("2020-09-01")
    resolution = Dates.Hour(1)
    ta = TimeSeries.TimeArray(range(initial_time; length=24, step=resolution), ones(24))
    ts = IS.SingleTimeSeries(data=ta, name="test")

    for i in 1:3
        name = "component_$(i)"
        component = IS.TestComponent(name, 5)
        IS.add_component!(data, component)
        geo_supplemental_attribute = IS.GeographicInfo()
        IS.add_supplemental_attribute!(data, component, geo_supplemental_attribute)
        IS.add_time_series!(data, geo_supplemental_attribute, ts)
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
    @test length(collect(IS.get_time_series_multiple(data, type=IS.SingleTimeSeries))) == 3
end
