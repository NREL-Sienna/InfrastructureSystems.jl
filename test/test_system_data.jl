@testset "Test components" begin
    data = IS.SystemData()

    name = "component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(data, component)

    component = IS.get_component(IS.TestComponent, data, name)
    @test component.name == name

    components = IS.get_components(IS.TestComponent, data)
    @test length(components) == 1

    @test length(
        IS.get_components(x -> (IS.get_val(x) != 5), IS.TestComponent, data),
    ) == 0
    @test length(
        IS.get_components(x -> (IS.get_val(x) == 5), IS.TestComponent, data),
    ) == 1

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
    @test isempty(data.component_uuids)

    IS.add_component!(data, component)
    components =
        IS.get_components_by_name(IS.InfrastructureSystemsComponent, data, name)
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
    ta = TimeSeries.TimeArray(
        range(initial_time; length = 24, step = resolution),
        ones(24),
    )
    ts = IS.SingleTimeSeries(; data = ta, name = "test")

    for i in 1:3
        name = "component_$(i)"
        component = IS.TestComponent(name, i)
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
    @test collect(IS.get_masked_components(x -> x.val == 2, IS.TestComponent, data)) ==
          [component]
    @test IS.get_masked_components_by_name(
        IS.InfrastructureSystemsComponent,
        data,
        "component_2",
    ) == [component]
    @test IS.get_time_series(IS.SingleTimeSeries, component, "test") isa
          IS.SingleTimeSeries
    @test IS.is_attached(component, data.masked_components)

    # This needs to return time series for masked components.
    @test length(
        collect(IS.get_time_series_multiple(data; type = IS.SingleTimeSeries)),
    ) ==
          3

    IS.remove_masked_component!(
        data,
        IS.get_masked_component(IS.TestComponent, data, "component_2"),
    )
    @test isempty(IS.get_masked_components(IS.TestComponent, data))
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
    @test IS.get_compression_settings(IS.SystemData(; time_series_in_memory = true)) ==
          none
    settings =
        IS.CompressionSettings(; enabled = true, type = IS.CompressionTypes.DEFLATE)
    @test IS.get_compression_settings(IS.SystemData(; compression = settings)) ==
          settings
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

    returned_it, returned_len =
        IS.check_time_series_consistency(data, IS.SingleTimeSeries)
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

    @test_throws IS.InvalidValue IS.check_time_series_consistency(
        data,
        IS.SingleTimeSeries,
    )
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

    @test_throws IS.InvalidValue IS.check_time_series_consistency(
        data,
        IS.SingleTimeSeries,
    )
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
    @test component === IS.get_component(data, IS.get_uuid(component))
end

@testset "Test component and time series counts" begin
    data = IS.SystemData()
    initial_time = Dates.DateTime("2020-09-01")
    resolution = Dates.Hour(1)
    ta = TimeSeries.TimeArray(
        range(initial_time; length = 24, step = resolution),
        ones(24),
    )
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
    ta = TimeSeries.TimeArray(
        range(initial_time; length = 24, step = resolution),
        ones(24),
    )
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
        @test IS.has_supplemental_attributes(c)
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

@testset "Test retrieval of supplemental_attributes" begin
    data = IS.SystemData()
    geo_supplemental_attribute = IS.GeographicInfo()
    attr1 = IS.TestSupplemental(; value = 1.0)
    attr2 = IS.TestSupplemental(; value = 2.0)
    component1 = IS.TestComponent("component1", 5)
    component2 = IS.TestComponent("component2", 7)

    @test_throws ArgumentError IS.add_supplemental_attribute!(
        data,
        component1,
        geo_supplemental_attribute,
    )

    IS.add_component!(data, component1)
    IS.add_component!(data, component2)
    IS.add_supplemental_attribute!(data, component1, geo_supplemental_attribute)
    IS.add_supplemental_attribute!(data, component2, geo_supplemental_attribute)
    IS.add_supplemental_attribute!(data, component1, attr1)
    IS.add_supplemental_attribute!(data, component2, attr2)
    @test IS.get_num_supplemental_attributes(data.attributes) == 3

    # Test all permutations of abstract vs concrete, system vs component, filter vs not.
    @test length(IS.get_supplemental_attributes(IS.SupplementalAttribute, data)) == 3
    @test length(
        IS.get_supplemental_attributes(IS.SupplementalAttribute, component1),
    ) == 2
    @test length(
        IS.get_supplemental_attributes(IS.SupplementalAttribute, component2),
    ) == 2
    @test length(
        IS.get_supplemental_attributes(
            x -> x isa IS.TestSupplemental,
            IS.SupplementalAttribute,
            data,
        ),
    ) == 2
    @test length(
        IS.get_supplemental_attributes(
            x -> x isa IS.TestSupplemental,
            IS.SupplementalAttribute,
            component1,
        ),
    ) == 1
    @test length(
        IS.get_supplemental_attributes(
            x -> x isa IS.TestSupplemental,
            IS.SupplementalAttribute,
            component2,
        ),
    ) == 1
    @test length(IS.get_supplemental_attributes(IS.TestSupplemental, data)) == 2
    @test length(IS.get_supplemental_attributes(IS.GeographicInfo, data)) == 1
    @test length(IS.get_supplemental_attributes(IS.GeographicInfo, component1)) == 1
    @test length(IS.get_supplemental_attributes(IS.TestSupplemental, component1)) == 1
    @test length(IS.get_supplemental_attributes(IS.TestSupplemental, component2)) == 1
    @test length(
        IS.get_supplemental_attributes(x -> x.value == 1.0, IS.TestSupplemental, data),
    ) == 1
    @test length(
        IS.get_supplemental_attributes(x -> x.value == 2.0, IS.TestSupplemental, data),
    ) == 1
    @test length(
        IS.get_supplemental_attributes(
            x -> x.value == 1.0,
            IS.TestSupplemental,
            component1,
        ),
    ) == 1
    @test length(
        IS.get_supplemental_attributes(
            x -> x.value == 2.0,
            IS.TestSupplemental,
            component1,
        ),
    ) == 0
    @test length(
        IS.get_supplemental_attributes(
            x -> x.value == 1.0,
            IS.TestSupplemental,
            component2,
        ),
    ) == 0
    @test length(
        IS.get_supplemental_attributes(
            x -> x.value == 2.0,
            IS.TestSupplemental,
            component2,
        ),
    ) == 1

    uuid1 = IS.get_uuid(attr1)
    uuid2 = IS.get_uuid(attr2)
    uuid3 = IS.get_uuid(geo_supplemental_attribute)
    @test IS.get_supplemental_attribute(data, uuid1) ===
          IS.get_supplemental_attribute(component1, uuid1)
    @test IS.get_supplemental_attribute(data, uuid2) ===
          IS.get_supplemental_attribute(component2, uuid2)
    @test IS.get_supplemental_attribute(data, uuid3) ===
          IS.get_supplemental_attribute(component1, uuid3)
    @test IS.get_supplemental_attribute(data, uuid3) ===
          IS.get_supplemental_attribute(component2, uuid3)
end

@testset "Test retrieval of components with a supplemental attribute" begin
    data = IS.SystemData()
    geo_supplemental_attribute = IS.GeographicInfo()
    component1 = IS.TestComponent("component1", 5)
    component2 = IS.TestComponent("component2", 7)
    IS.add_component!(data, component1)
    IS.add_component!(data, component2)
    IS.add_supplemental_attribute!(data, component1, geo_supplemental_attribute)
    IS.add_supplemental_attribute!(data, component2, geo_supplemental_attribute)
    components = IS.get_components(data, geo_supplemental_attribute)
    @test length(components) == 2
    sort!(components; by = x -> x.name)
    @test components[1] === component1
    @test components[2] === component2
end

@testset "Test assign_new_uuid" begin
    data = IS.SystemData()

    name = "component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(data, component)
    uuid1 = IS.get_uuid(component)
    IS.assign_new_uuid!(data, component)
    uuid2 = IS.get_uuid(component)
    @test uuid1 != uuid2
    @test IS.get_component(IS.TestComponent, data, name).name == name
end

@testset "Test bulk add of time series" begin
    for in_memory in (false, true)
        sys = IS.SystemData(; time_series_in_memory = in_memory)
        @test IS.stores_time_series_in_memory(sys) == in_memory
        initial_time = Dates.DateTime("2020-09-01")
        resolution = Dates.Hour(1)
        len = 24
        timestamps = range(initial_time; length = len, step = resolution)
        arrays = [TimeSeries.TimeArray(timestamps, rand(len)) for _ in 1:5]
        ts_name = "test"
        component_names = String[]

        IS.open_time_series_store!(sys, "r+") do
            for (i, ta) in enumerate(arrays)
                name = "component_$(i)"
                component = IS.TestComponent(name, 3)
                IS.add_component!(sys, component)
                push!(component_names, name)
                ts = IS.SingleTimeSeries(; data = ta, name = ts_name)
                IS.add_time_series!(sys, component, ts)
            end
        end

        IS.open_time_series_store!(sys, "r") do
            for (i, expected_array) in enumerate(arrays)
                name = component_names[i]
                component = IS.get_component(IS.TestComponent, sys, name)
                @test !isnothing(component)
                ts = IS.get_time_series(IS.SingleTimeSeries, component, ts_name)
                @test ts.data == expected_array
            end
        end
    end
end

@testset "Test bulk add of time series via function with args and kwargs" begin
    function add_time_series(sys_data, component, ta; ts_name)
        ts = IS.SingleTimeSeries(; data = ta, name = ts_name)
        IS.add_time_series!(sys_data, component, ts)
    end

    for in_memory in (false, true)
        sys = IS.SystemData(; time_series_in_memory = in_memory)
        initial_time = Dates.DateTime("2020-09-01")
        resolution = Dates.Hour(1)
        len = 24
        timestamps = range(initial_time; length = len, step = resolution)
        ta = TimeSeries.TimeArray(timestamps, rand(len))
        ts_name = "test"
        name = "component"
        component = IS.TestComponent(name, 3)
        IS.add_component!(sys, component)
        IS.open_time_series_store!(
            add_time_series,
            sys,
            "r+",
            sys,
            component,
            ta;
            ts_name = ts_name,
        )

        ts = IS.get_time_series(IS.SingleTimeSeries, component, ts_name)
        @test ts.data == ta
    end
end

@testset "Test list_time_series_resolutions" begin
    sys = IS.SystemData()
    initial_time = Dates.DateTime("2020-09-01")
    resolution1 = Dates.Minute(5)
    resolution2 = Dates.Hour(1)
    len = 24
    timestamps1 = range(initial_time; length = len, step = resolution1)
    timestamps2 = range(initial_time; length = len, step = resolution2)
    array1 = TimeSeries.TimeArray(timestamps1, rand(len))
    array2 = TimeSeries.TimeArray(timestamps2, rand(len))
    name = "component"
    component = IS.TestComponent(name, 3)
    IS.add_component!(sys, component)
    ts1 = IS.SingleTimeSeries(; data = array1, name = "test1")
    ts2 = IS.SingleTimeSeries(; data = array2, name = "test2")
    IS.add_time_series!(sys, component, ts1)
    IS.add_time_series!(sys, component, ts2)

    other_time = initial_time + resolution2
    horizon = 24
    data = SortedDict(initial_time => rand(horizon), other_time => rand(horizon))

    forecast = IS.Deterministic(; data = data, name = "test3", resolution = resolution2)
    IS.add_time_series!(sys, component, forecast)
    @test IS.list_time_series_resolutions(sys) ==
          [Dates.Minute(5), Dates.Hour(1)]
    @test IS.list_time_series_resolutions(
        sys;
        time_series_type = IS.SingleTimeSeries,
    ) == [Dates.Minute(5), Dates.Hour(1)]
    @test IS.list_time_series_resolutions(
        sys;
        time_series_type = IS.Deterministic,
    ) == [Dates.Hour(1)]
end

@testset "Test deepcopy of system" begin
    for in_memory in (false, true)
        sys = IS.SystemData(; time_series_in_memory = in_memory)
        initial_time = Dates.DateTime("2020-09-01")
        resolution = Dates.Hour(1)
        len = 24
        timestamps = range(initial_time; length = len, step = resolution)
        array = TimeSeries.TimeArray(timestamps, rand(len))
        ts_name = "test"
        name = "component"
        component = IS.TestComponent(name, 3)
        IS.add_component!(sys, component)
        ts = IS.SingleTimeSeries(; data = array, name = ts_name)
        IS.add_time_series!(sys, component, ts)
        sys2 = deepcopy(sys)
        component2 = IS.get_component(IS.TestComponent, sys2, name)
        ts2 = IS.get_time_series(IS.SingleTimeSeries, component2, ts_name)
        @test ts2.data == array
    end
end
