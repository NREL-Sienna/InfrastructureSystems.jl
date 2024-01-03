
@testset "Test components" begin
    data = IS.SystemData()

    name = "component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(data, component)

    component = IS.get_component(IS.TestComponent, data, name)
    @test component.name == name

    components = IS.get_components(IS.TestComponent, data)
    @test length(components) == 1

    @test length(IS.get_components(x -> (IS.get_val(x) != 5), IS.TestComponent, data)) == 0
    @test length(IS.get_components(x -> (IS.get_val(x) == 5), IS.TestComponent, data)) == 1

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

@testset "Test change component name" begin
    data = IS.SystemData()
    name = "component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(data, component)

    new_name = "component1-new"
    IS.set_name!(data, component, new_name)
    @test IS.get_name(component) == new_name
    @test IS.get_component(typeof(component), data, new_name) === component

    IS.add_component!(data, IS.TestComponent("component2", 6))
    @test_throws ArgumentError IS.set_name!(data, component, "component2")

    component2 = IS.TestComponent("unattached", 5)
    @test_throws ArgumentError IS.set_name!(data, component2, new_name)
end

@testset "Test masked components" begin
    data = IS.SystemData()
    initial_time = Dates.DateTime("2020-09-01")
    resolution = Dates.Hour(1)
    ta = TimeSeries.TimeArray(range(initial_time; length = 24, step = resolution), ones(24))
    ts = IS.SingleTimeSeries(; data = ta, name = "test")

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
    @test length(collect(IS.get_time_series_multiple(data; type = IS.SingleTimeSeries))) ==
          3
end

@testset "Test compare_values" begin
    component1 = IS.TestComponent("a", 5)
    component2 = IS.TestComponent("a", 5)
    @test IS.compare_values(component1, component2)
    @test(
        @test_logs(
            (:error, r"not match"),
            match_mode = :any,
            !IS.compare_values(component1, component2; compare_uuids = true)
        )
    )
    component2.name = "b"
    @test(
        @test_logs(
            (:error, r"not match"),
            match_mode = :any,
            !IS.compare_values(component1, component2; compare_uuids = false)
        )
    )

    data1 = IS.SystemData()
    IS.add_component!(data1, component1)
    IS.add_component!(data1, component2)
    @test(
        @test_logs(
            (:error, r"not match"),
            match_mode = :any,
            !IS.compare_values(
                IS.get_component(IS.TestComponent, data1, "a"),
                IS.get_component(IS.TestComponent, data1, "b"),
            )
        )
    )

    # Creating two systems in the same way should produce the same values aside from UUIDs.
    data2 = IS.SystemData()
    IS.add_component!(data2, IS.TestComponent("a", 5))
    IS.add_component!(data2, IS.TestComponent("b", 5))

    @test IS.compare_values(data1, data2)
    @test IS.compare_values(
        IS.get_component(IS.TestComponent, data1, "a"),
        IS.get_component(IS.TestComponent, data2, "a"),
    )
end

@testset "Test compression settings" begin
    none = IS.CompressionSettings(; enabled = false)
    @test IS.get_compression_settings(IS.SystemData()) == none
    @test IS.get_compression_settings(IS.SystemData(; time_series_in_memory = true)) == none
    settings = IS.CompressionSettings(; enabled = true, type = IS.CompressionTypes.DEFLATE)
    @test IS.get_compression_settings(IS.SystemData(; compression = settings)) == settings
end

@testset "Test single time series consistency" begin
    data = IS.SystemData()
    initial_time = Dates.DateTime("2020-09-01")
    resolution = Dates.Hour(1)
    len = 24
    ta = TimeSeries.TimeArray(
        range(initial_time; length = len, step = resolution),
        ones(len),
    )
    ts = IS.SingleTimeSeries(; data = ta, name = "test")

    for i in 1:2
        name = "component_$(i)"
        component = IS.TestComponent(name, 5)
        IS.add_component!(data, component)
        IS.add_time_series!(data, component, ts)
    end

    returned_it, returned_len = IS.check_time_series_consistency(data, IS.SingleTimeSeries)
    @test returned_it == initial_time
    @test returned_len == len
end

@testset "Test single time series initial time inconsistency" begin
    data = IS.SystemData()
    initial_time = Dates.DateTime("2020-09-01")
    resolution = Dates.Hour(1)
    len = 24

    for i in 1:2
        it = initial_time + resolution * i
        ta = TimeSeries.TimeArray(range(it; length = len, step = resolution), ones(len))
        ts = IS.SingleTimeSeries(; data = ta, name = "test")
        name = "component_$(i)"
        component = IS.TestComponent(name, 5)
        IS.add_component!(data, component)
        IS.add_time_series!(data, component, ts)
    end

    @test_throws IS.InvalidValue IS.check_time_series_consistency(data, IS.SingleTimeSeries)
end

@testset "Test single time series length inconsistency" begin
    data = IS.SystemData()
    initial_time = Dates.DateTime("2020-09-01")
    resolution = Dates.Hour(1)
    len = 24

    for i in 1:2
        len += i
        ta = TimeSeries.TimeArray(
            range(initial_time; length = len, step = resolution),
            ones(len),
        )
        ts = IS.SingleTimeSeries(; data = ta, name = "test")
        name = "component_$(i)"
        component = IS.TestComponent(name, 5)
        IS.add_component!(data, component)
        IS.add_time_series!(data, component, ts)
    end

    @test_throws IS.InvalidValue IS.check_time_series_consistency(data, IS.SingleTimeSeries)
end

@testset "Test check_components" begin
    data = IS.SystemData()

    for i in 1:5
        name = "component_$i"
        component = IS.TestComponent(name, i)
        IS.add_component!(data, component)
    end

    IS.check_components(data)
    IS.check_components(data, IS.get_components(IS.TestComponent, data))
    IS.check_components(data, collect(IS.get_components(IS.TestComponent, data)))
    IS.check_components(data, IS.TestComponent)
    component = IS.get_component(IS.TestComponent, data, "component_3")
    IS.check_component(data, component)
end

@testset "Test component and time series counts" begin
    data = IS.SystemData()
    initial_time = Dates.DateTime("2020-09-01")
    resolution = Dates.Hour(1)
    ta = TimeSeries.TimeArray(range(initial_time; length = 24, step = resolution), ones(24))
    ts = IS.SingleTimeSeries(; data = ta, name = "test")

    for i in 1:5
        name = "component_$(i)"
        component = IS.TestComponent(name, 3)
        IS.add_component!(data, component)
        IS.add_time_series!(data, component, ts)
    end

    c_counts = IS.get_component_counts_by_type(data)
    @test length(c_counts) == 1
    @test c_counts[1]["type"] == "TestComponent"
    @test c_counts[1]["count"] == 5

    ts_counts = IS.get_time_series_counts_by_type(data)
    @test length(ts_counts) == 1
    @test ts_counts[1]["type"] == "SingleTimeSeries"
    @test ts_counts[1]["count"] == 5
end

@testset "Test component and attributes" begin
    data = IS.SystemData()
    initial_time = Dates.DateTime("2020-09-01")
    resolution = Dates.Hour(1)
    ta = TimeSeries.TimeArray(range(initial_time; length = 24, step = resolution), ones(24))
    ts = IS.SingleTimeSeries(; data = ta, name = "test")

    for i in 1:5
        name = "component_$(i)"
        component = IS.TestComponent(name, 3)
        IS.add_component!(data, component)
        IS.add_time_series!(data, component, ts)
        geo_info = IS.GeographicInfo()
        IS.add_supplemental_attribute!(data, component, geo_info)
    end

    for c in IS.get_components(IS.TestComponent, data)
        @test IS.has_supplemental_attributes(IS.GeographicInfo, c)
    end

    @test length(IS.get_supplemental_attributes(IS.GeographicInfo, data)) == 5

    i = 0
    for component in IS.iterate_supplemental_attributes(data)
        i += 1
    end
    @test i == 5

    attributes = IS.get_supplemental_attributes(IS.GeographicInfo, data)
    io = IOBuffer()
    show(io, "text/plain", attributes)
    output = String(take!(io))
    expected = "GeographicInfo: $i"
    @test occursin(expected, output)

    attribute_removed = collect(attributes)[1]
    IS.remove_supplemental_attribute!(data, attribute_removed)

    attributes = IS.get_supplemental_attributes(IS.GeographicInfo, data)
    @test length(attributes) == 4
    @test IS.get_uuid(attribute_removed) ∉ IS.get_uuid.(attributes)

    IS.remove_supplemental_attributes!(IS.GeographicInfo, data)
    attributes = IS.get_supplemental_attributes(IS.GeographicInfo, data)
    @test length(attributes) == 0
end
