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
    @test isempty(IS.get_component_uuids(geo_supplemental_attribute))
    IS.clear_supplemental_attributes!(container)
    supplemental_attributes = IS.get_supplemental_attributes(IS.GeographicInfo, container)
    @test length(supplemental_attributes) == 0
end

@testset "Test remove_supplemental_attribute" begin
    container = IS.SupplementalAttributes(IS.InMemoryTimeSeriesStorage())
    geo_supplemental_attribute = IS.GeographicInfo()
    component = IS.TestComponent("component1", 5)
    IS.add_supplemental_attribute!(container, component, geo_supplemental_attribute)
    @test IS.get_num_supplemental_attributes(container) == 1

    IS.detach_component!(geo_supplemental_attribute, component)
    IS.detach_supplemental_attribute!(component, geo_supplemental_attribute)
    @test isempty(IS.get_supplemental_attributes_container(component))
    @test isempty(IS.get_component_uuids(geo_supplemental_attribute))
end

@testset "Test supplemental attribute attached to multiple components" begin
    data = IS.SystemData()
    geo_supplemental_attribute = IS.GeographicInfo()
    component1 = IS.TestComponent("component1", 5)
    component2 = IS.TestComponent("component2", 7)
    IS.add_component!(data, component1)
    IS.add_component!(data, component2)
    IS.add_supplemental_attribute!(data, component1, geo_supplemental_attribute)
    IS.add_supplemental_attribute!(data, component2, geo_supplemental_attribute)
    @test IS.get_num_supplemental_attributes(data.attributes) == 1

    IS.remove_supplemental_attribute!(data, component1, geo_supplemental_attribute)
    @test IS.get_num_supplemental_attributes(data.attributes) == 1
    IS.remove_supplemental_attribute!(data, component2, geo_supplemental_attribute)
    @test IS.get_num_supplemental_attributes(data.attributes) == 0
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
    ta = TimeSeries.TimeArray(range(initial_time; length = 24, step = resolution), ones(24))
    ts = IS.SingleTimeSeries(; data = ta, name = "test")

    for i in 1:3
        name = "component_$(i)"
        component = IS.TestComponent(name, 5)
        IS.add_component!(data, component)
        supp_attribute = IS.TestSupplemental(; value = Float64(i))
        IS.add_supplemental_attribute!(data, component, supp_attribute)
        IS.add_time_series!(data, supp_attribute, ts)
    end

    for attribute in IS.iterate_supplemental_attributes(data)
        @test IS.get_time_series_container(attribute) !== nothing
        ts_ = IS.get_time_series(IS.SingleTimeSeries, attribute, "test")
        @test IS.get_initial_timestamp(ts_) == initial_time
    end
end
