@testset "Test add forecasts on the fly from dict" begin
    sys = IS.SystemData()
    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(sys, component)

    initial_time = Dates.DateTime("2020-09-01")
    resolution = Dates.Hour(1)

    data = TimeSeries.TimeArray(
        range(initial_time; length = 365, step = resolution),
        ones(365),
    )
    other_time = initial_time + resolution
    name = "test"
    horizon = 24
    data = SortedDict(initial_time => ones(horizon), other_time => ones(horizon))

    forecast = IS.Deterministic(
        data = data,
        name = name,
        initial_timestamp = initial_time,
        horizon = horizon,
        resolution = resolution,
    )
    IS.add_time_series!(sys, component, forecast)
    var1 = IS.get_time_series(IS.Deterministic, component, name; start_time = initial_time)
    @test length(var1.data) == 1
    var2 = IS.get_time_series(
        IS.Deterministic,
        component,
        name;
        start_time = initial_time,
        count = 2,
    )
    @test length(var2.data) == 2
    var3 = IS.get_time_series(IS.Deterministic, component, name; start_time = other_time)
    @test length(var2.data) == 2
    # Throws errors
    @test_throws ArgumentError IS.get_time_series(
        IS.Deterministic,
        component,
        name;
        start_time = initial_time,
        count = 3,
    )
    @test_throws ArgumentError IS.get_time_series(
        IS.Deterministic,
        component,
        name;
        start_time = other_time,
        count = 2,
    )

    count = IS.get_count(var2)
    @test count == 2

    window1 = IS.get_window(var2, initial_time)
    @assert window1 isa TimeSeries.TimeArray
    @assert TimeSeries.timestamp(window1)[1] == initial_time
    window2 = IS.get_window(var2, other_time)
    @assert window2 isa TimeSeries.TimeArray
    @assert TimeSeries.timestamp(window2)[1] == other_time

    found = 0
    for ta in IS.iterate_windows(var2)
        @test ta isa TimeSeries.TimeArray
        found += 1
        if found == 1
            @test TimeSeries.timestamp(ta)[1] == initial_time
        else
            @test TimeSeries.timestamp(ta)[1] == other_time
        end
    end
    @test found == count

    @test IS.get_uuid(forecast) == IS.get_uuid(var1)
    @test IS.get_uuid(forecast) == IS.get_uuid(var2)
end

@testset "Test add Deterministic" begin
    initial_time = Dates.DateTime("2020-09-01")
    resolution = Dates.Hour(1)
    other_time = initial_time + resolution
    name = "test"
    horizon = 24
    data_vec = Dict(initial_time => ones(horizon), other_time => ones(horizon))
    data_tuple =
        Dict(initial_time => tuple(ones(horizon)...), other_time => tuple(ones(horizon)...))
    for d in [data_vec, data_tuple]
        @testset "Add deterministic from $(typeof(d))" begin
            sys = IS.SystemData()
            component_name = "Component1"
            component = IS.TestComponent(component_name, 5)
            IS.add_component!(sys, component)
            forecast = IS.Deterministic(name, d; resolution = resolution)
            @test IS.get_initial_timestamp(forecast) == initial_time
            IS.add_time_series!(sys, component, forecast)
            @test IS.has_time_series(component)
        end
    end

    data_ts = Dict(
        initial_time => TimeSeries.TimeArray(
            range(initial_time; length = horizon, step = resolution),
            ones(horizon),
        ),
        other_time => TimeSeries.TimeArray(
            range(other_time; length = horizon, step = resolution),
            ones(horizon),
        ),
    )
    sys = IS.SystemData()
    component_name = "Component1"
    component = IS.TestComponent(component_name, 5)
    IS.add_component!(sys, component)
    forecast = IS.Deterministic(name, data_ts)
    @test IS.get_initial_timestamp(forecast) == initial_time
    IS.add_time_series!(sys, component, forecast)
    @test IS.has_time_series(component)

    data_ts_two_cols = Dict(
        initial_time => TimeSeries.TimeArray(
            range(initial_time; length = horizon, step = resolution),
            ones(horizon, 2),
        ),
        other_time => TimeSeries.TimeArray(
            range(other_time; length = horizon, step = resolution),
            ones(horizon, 2),
        ),
    )
    sys = IS.SystemData()
    component_name = "Component1"
    component = IS.TestComponent(component_name, 5)
    IS.add_component!(sys, component)
    @test_throws ArgumentError IS.Deterministic(name, data_ts_two_cols)
end

@testset "Test add Probabilistic" begin
    initial_time = Dates.DateTime("2020-09-01")
    resolution = Dates.Hour(1)
    other_time = initial_time + resolution
    name = "test"
    horizon = 24
    data_vec = Dict(initial_time => ones(horizon, 99), other_time => ones(horizon, 99))
    d = data_vec
    sys = IS.SystemData()
    component_name = "Component1"
    component = IS.TestComponent(component_name, 5)
    IS.add_component!(sys, component)
    forecast = IS.Probabilistic(name, d, ones(99); resolution = resolution)
    IS.add_time_series!(sys, component, forecast)
    @test IS.has_time_series(component)
    @test IS.get_initial_timestamp(forecast) == initial_time
    forecast_retrieved =
        IS.get_time_series(IS.Probabilistic, component, "test"; start_time = initial_time)
    @test IS.get_initial_timestamp(forecast_retrieved) == initial_time
end

@testset "Test add SingleTimeSeries" begin
    sys = IS.SystemData()
    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(sys, component)

    initial_time = Dates.DateTime("2020-09-01")
    resolution = Dates.Hour(1)
    other_time = initial_time + resolution

    data = TimeSeries.TimeArray(
        range(initial_time; length = 365, step = resolution),
        ones(365),
    )
    data = IS.SingleTimeSeries(data = data, name = "test_c")
    IS.add_time_series!(sys, component, data)
    ts1 = IS.get_time_series(
        IS.SingleTimeSeries,
        component,
        "test_c";
        start_time = initial_time,
        len = 12,
    )
    @test length(IS.get_data(ts1)) == 12
    ts2 = IS.get_time_series(
        IS.SingleTimeSeries,
        component,
        "test_c";
        start_time = initial_time + Dates.Day(1),
        len = 12,
    )
    @test length(IS.get_data(ts2)) == 12
    ts3 = IS.get_time_series(
        IS.SingleTimeSeries,
        component,
        "test_c";
        start_time = initial_time + Dates.Day(1),
    )
    @test length(IS.get_data(ts3)) == 341
    #Throws errors
    @test_throws ArgumentError IS.get_time_series(
        IS.SingleTimeSeries,
        component,
        "test_c";
        start_time = initial_time,
        len = 1200,
    )
    @test_throws ArgumentError IS.get_time_series(
        IS.SingleTimeSeries,
        component,
        "test_c";
        start_time = initial_time - Dates.Day(10),
        len = 12,
    )

    # Conflicting resolution
    data = TimeSeries.TimeArray(
        range(initial_time; length = 365, step = Dates.Minute(5)),
        ones(365),
    )
    data = IS.SingleTimeSeries(data = data, name = "test_d")
    @test_throws IS.ConflictingInputsError IS.add_time_series!(sys, component, data)
end

@testset "Test read_time_series_file_metadata" begin
    file = joinpath(FORECASTS_DIR, "ComponentsAsColumnsNoTime.json")
    time_series = IS.read_time_series_file_metadata(file)
    @test length(time_series) == 1

    for time_series in time_series
        @test isfile(time_series.data_file)
    end
end

@testset "Test add_time_series from file" begin
    data = IS.SystemData()

    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(data, component)
    @test !IS.has_time_series(component)

    file = joinpath(FORECASTS_DIR, "ComponentsAsColumnsNoTime.json")
    IS.add_time_series_from_file_metadata!(data, IS.InfrastructureSystemsComponent, file)
    @test IS.has_time_series(component)

    all_time_series = get_all_time_series(data)
    @test length(all_time_series) == 1
    time_series = all_time_series[1]
    @test time_series isa IS.SingleTimeSeries

    time_series2 = IS.get_time_series(
        typeof(time_series),
        component,
        IS.get_name(time_series);
        start_time = IS.get_initial_time(time_series),
    )
    @test length(time_series) == length(time_series2)
    @test IS.get_initial_timestamp(time_series) == IS.get_initial_timestamp(time_series2)

    it = IS.get_initial_timestamp(time_series)

    all_time_series = get_all_time_series(data)
    @test length(collect(all_time_series)) == 1
    @test IS.get_time_series_resolution(data) == IS.get_resolution(time_series)

    data = IS.SystemData()
    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(data, component)
    @test !IS.has_time_series(component)
    file = joinpath(FORECASTS_DIR, "ForecastPointers.json")
    IS.add_time_series_from_file_metadata!(data, IS.InfrastructureSystemsComponent, file)
    @test IS.has_time_series(component)

    sys = IS.SystemData()
    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(sys, component)
    @test !IS.has_time_series(component)
    file = joinpath(FORECASTS_DIR, "DateTimeAsColumnDeterministic.csv")
    raw_data = IS.read_time_series(IS.Deterministic, file, "Component1")
    data = IS.Deterministic("test", file, component; resolution = Dates.Hour(1))
    IS.add_time_series!(sys, component, data)
    @test IS.has_time_series(component)
    ini_time = IS.get_initial_timestamp(data)
    retrieved_data =
        IS.get_time_series(IS.Deterministic, component, "test"; start_time = ini_time)
    @test IS.get_name(data) == IS.get_name(retrieved_data)
    @test IS.get_resolution(data) == IS.get_resolution(retrieved_data)
end

@testset "Test add_time_series" begin
    sys = IS.SystemData()
    name = "Component1"
    component_val = 5
    component = IS.TestComponent(name, component_val)
    IS.add_component!(sys, component)

    dates = create_dates("2020-01-01T00:00:00", Dates.Hour(1), "2020-01-01T23:00:00")
    data = collect(1:24)
    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    name = "val"
    ts = IS.SingleTimeSeries(name = name, data = ta, scaling_factor_multiplier = IS.get_val)
    IS.add_time_series!(sys, component, ts)
    ts = IS.get_time_series(IS.SingleTimeSeries, component, name; start_time = dates[1])
    @test ts isa IS.SingleTimeSeries

    name = "Component2"
    component2 = IS.TestComponent(name, component_val)
    @test_throws ArgumentError IS.add_time_series!(sys, component2, ts)

    # The component name will exist but not the component.
    component3 = IS.TestComponent(name, component_val)
    @test_throws ArgumentError IS.add_time_series!(sys, component3, ts)
end

@testset "Test add_time_series multiple components" begin
    sys = IS.SystemData()
    components = []
    len = 3
    for i in 1:len
        component = IS.TestComponent(string(i), i)
        IS.add_component!(sys, component)
        push!(components, component)
    end

    initial_time = Dates.DateTime("2020-01-01T00:00:00")
    end_time = Dates.DateTime("2020-01-01T23:00:00")
    dates = collect(initial_time:Dates.Hour(1):end_time)
    data = collect(1:24)
    ta = TimeSeries.TimeArray(dates, data, ["1"])
    name = "val"
    ts = IS.SingleTimeSeries(name = name, data = ta, scaling_factor_multiplier = IS.get_val)
    IS.add_time_series!(sys, components, ts)

    hash_ta_main = nothing
    for i in 1:len
        component = IS.get_component(IS.TestComponent, sys, string(i))
        ts = IS.get_time_series(IS.SingleTimeSeries, component, name)
        hash_ta = hash(IS.get_data(ts))
        if i == 1
            hash_ta_main = hash_ta
        else
            @test hash_ta == hash_ta_main
        end
    end

    ts_storage = sys.time_series_storage
    @test ts_storage isa IS.Hdf5TimeSeriesStorage
    @test IS.get_num_time_series(ts_storage) == 1
end

@testset "Test get_time_series_multiple" begin
    sys = IS.SystemData()
    name = "Component1"
    component_val = 5
    component = IS.TestComponent(name, component_val)
    IS.add_component!(sys, component)
    initial_time1 = Dates.DateTime("2020-01-01T00:00:00")
    initial_time2 = Dates.DateTime("2020-01-02T00:00:00")

    dates1 = collect(initial_time1:Dates.Hour(1):Dates.DateTime("2020-01-01T23:00:00"))
    dates2 = collect(initial_time2:Dates.Hour(1):Dates.DateTime("2020-01-02T23:00:00"))
    data1 = collect(1:24)
    data2 = collect(25:48)
    ta1 = TimeSeries.TimeArray(dates1, data1, [IS.get_name(component)])
    ta2 = TimeSeries.TimeArray(dates2, data2, [IS.get_name(component)])
    time_series1 = IS.SingleTimeSeries(
        name = "val",
        data = ta1,
        scaling_factor_multiplier = IS.get_val,
    )
    time_series2 = IS.SingleTimeSeries(
        name = "val2",
        data = ta2,
        scaling_factor_multiplier = IS.get_val,
    )
    IS.add_time_series!(sys, component, time_series1)
    IS.add_time_series!(sys, component, time_series2)

    @test length(collect(IS.get_time_series_multiple(sys))) == 2
    @test length(collect(IS.get_time_series_multiple(component))) == 2
    @test length(collect(IS.get_time_series_multiple(sys))) == 2

    @test length(collect(IS.get_time_series_multiple(sys; type = IS.SingleTimeSeries))) == 2
    @test length(collect(IS.get_time_series_multiple(sys; type = IS.Probabilistic))) == 0

    time_series = collect(IS.get_time_series_multiple(sys))
    @test length(time_series) == 2

    @test length(collect(IS.get_time_series_multiple(sys; name = "val"))) == 1
    @test length(collect(IS.get_time_series_multiple(sys; name = "bad_name"))) == 0

    filter_func = x -> TimeSeries.values(IS.get_data(x))[12] == 12
    @test length(collect(IS.get_time_series_multiple(sys, filter_func; name = "val2"))) == 0
end

@testset "Test add_time_series from TimeArray" begin
    sys = IS.SystemData()
    name = "Component1"
    component_val = 5
    component = IS.TestComponent(name, component_val)
    IS.add_component!(sys, component)

    dates = create_dates("2020-01-01T00:00:00", Dates.Hour(1), "2020-01-01T23:00:00")
    data = collect(1:24)
    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    name = "val"
    ts = IS.SingleTimeSeries(name, ta; scaling_factor_multiplier = IS.get_val)
    IS.add_time_series!(sys, component, ts)
    time_series = IS.get_time_series(IS.SingleTimeSeries, component, name)
    @test time_series isa IS.SingleTimeSeries
end

@testset "Test remove_time_series" begin
    data = create_system_data(; with_time_series = true)
    components = collect(IS.iterate_components(data))
    @test length(components) == 1
    component = components[1]
    time_series = get_all_time_series(data)
    @test length(get_all_time_series(data)) == 1

    time_series = time_series[1]
    IS.remove_time_series!(typeof(time_series), data, component, IS.get_name(time_series))

    @test length(get_all_time_series(data)) == 0
    @test IS.get_num_time_series(data.time_series_storage) == 0
end

@testset "Test clear_time_series" begin
    data = create_system_data(; with_time_series = true)
    IS.clear_time_series!(data)
    @test length(get_all_time_series(data)) == 0
end

@testset "Test that remove_component removes time_series" begin
    data = create_system_data(; with_time_series = true)

    components = collect(IS.get_components(IS.InfrastructureSystemsComponent, data))
    @test length(components) == 1
    component = components[1]

    all_time_series = collect(IS.get_time_series_multiple(data))
    @test length(all_time_series) == 1
    time_series = all_time_series[1]
    @test IS.get_num_time_series(data.time_series_storage) == 1

    IS.remove_component!(data, component)
    @test length(collect(IS.get_time_series_multiple(component))) == 0
    @test length(collect(IS.get_components(IS.InfrastructureSystemsComponent, data))) == 0
    @test length(get_all_time_series(data)) == 0
    @test IS.get_num_time_series(data.time_series_storage) == 0
end

@testset "Test get_time_series_array" begin
    sys = IS.SystemData()
    name = "Component1"
    component_val = 5
    component = IS.TestComponent(name, component_val)
    IS.add_component!(sys, component)

    dates = create_dates("2020-01-01T00:00:00", Dates.Hour(1), "2020-01-01T23:00:00")
    data = collect(1:24)
    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    name = "val"
    ts = IS.SingleTimeSeries(
        name,
        ta;
        normalization_factor = 1.0,
        scaling_factor_multiplier = IS.get_val,
    )
    IS.add_time_series!(sys, component, ts)
    time_series = IS.get_time_series(IS.SingleTimeSeries, component, name)

    # Test both versions of the function.
    vals = IS.get_time_series_array(component, time_series)
    @test TimeSeries.timestamp(vals) == dates
    @test TimeSeries.values(vals) == data .* component_val

    vals2 = IS.get_time_series_array(IS.SingleTimeSeries, component, name)
    @test TimeSeries.timestamp(vals2) == dates
    @test TimeSeries.values(vals2) == data .* component_val
end

@testset "Test get subset of time_series" begin
    sys = create_system_data()
    components = collect(IS.get_components(IS.InfrastructureSystemsComponent, sys))
    @test length(components) == 1
    component = components[1]

    dates = create_dates("2020-01-01T00:00:00", Dates.Hour(1), "2020-01-01T23:00:00")
    data = collect(1:24)

    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    name = "val"
    ts = IS.SingleTimeSeries(name, ta)
    IS.add_time_series!(sys, component, ts)

    time_series =
        IS.get_time_series(IS.SingleTimeSeries, component, name; start_time = dates[1])
    @test TimeSeries.timestamp(IS.get_data(time_series))[1] == dates[1]
    @test length(time_series) == 24

    time_series =
        IS.get_time_series(IS.SingleTimeSeries, component, name; start_time = dates[3])
    @test TimeSeries.timestamp(IS.get_data(time_series))[1] == dates[3]
    @test length(time_series) == 22

    time_series = IS.get_time_series(
        IS.SingleTimeSeries,
        component,
        name;
        start_time = dates[5],
        len = 10,
    )
    @test TimeSeries.timestamp(IS.get_data(time_series))[1] == dates[5]
    @test length(time_series) == 10
end

@testset "Test copy time_series no name mapping" begin
    sys = create_system_data()
    components = collect(IS.get_components(IS.InfrastructureSystemsComponent, sys))
    @test length(components) == 1
    component = components[1]

    initial_time = Dates.DateTime("2020-01-01T00:00:00")
    dates = collect(initial_time:Dates.Hour(1):Dates.DateTime("2020-01-01T23:00:00"))
    data = collect(1:24)

    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    name = "val"
    ts = IS.SingleTimeSeries(name, ta)
    IS.add_time_series!(sys, component, ts)

    component2 = IS.TestComponent("component2", 6)
    IS.add_component!(sys, component2)
    IS.copy_time_series!(component2, component)
    time_series = IS.get_time_series(IS.SingleTimeSeries, component2, name)
    @test time_series isa IS.SingleTimeSeries
    @test IS.get_initial_time(time_series) == initial_time
    @test IS.get_name(time_series) == name
end

@testset "Test copy time_series name mapping" begin
    sys = create_system_data()
    components = collect(IS.get_components(IS.InfrastructureSystemsComponent, sys))
    @test length(components) == 1
    component = components[1]

    initial_time = Dates.DateTime("2020-01-01T00:00:00")
    dates = collect(initial_time:Dates.Hour(1):Dates.DateTime("2020-01-01T23:00:00"))
    data = collect(1:24)

    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    name1 = "val1"
    ts = IS.SingleTimeSeries(name1, ta)
    IS.add_time_series!(sys, component, ts)

    component2 = IS.TestComponent("component2", 6)
    IS.add_component!(sys, component2)
    name2 = "val2"
    name_mapping = Dict(name1 => name2)
    IS.copy_time_series!(component2, component; name_mapping = name_mapping)
    time_series = IS.get_time_series(IS.SingleTimeSeries, component2, name2)
    @test time_series isa IS.SingleTimeSeries
    @test IS.get_initial_time(time_series) == initial_time
    @test IS.get_name(time_series) == name2
end

@testset "Test copy time_series name mapping, missing name" begin
    sys = create_system_data()
    components = collect(IS.get_components(IS.InfrastructureSystemsComponent, sys))
    @test length(components) == 1
    component = components[1]

    initial_time1 = Dates.DateTime("2020-01-01T00:00:00")
    end_time1 = Dates.DateTime("2020-01-01T23:00:00")
    dates1 = collect(initial_time1:Dates.Hour(1):end_time1)
    initial_time2 = Dates.DateTime("2020-01-02T00:00:00")
    end_time2 = Dates.DateTime("2020-01-02T23:00:00")
    dates2 = collect(initial_time2:Dates.Hour(1):end_time2)
    data = collect(1:24)

    ta1 = TimeSeries.TimeArray(dates1, data, [IS.get_name(component)])
    ta2 = TimeSeries.TimeArray(dates2, data, [IS.get_name(component)])
    name1 = "val1"
    name2a = "val2a"
    ts1 = IS.SingleTimeSeries(name1, ta1)
    ts2 = IS.SingleTimeSeries(name2a, ta2)
    IS.add_time_series!(sys, component, ts1)
    IS.add_time_series!(sys, component, ts2)

    component2 = IS.TestComponent("component2", 6)
    IS.add_component!(sys, component2)
    name2b = "val2b"
    name_mapping = Dict(name2a => name2b)
    IS.copy_time_series!(component2, component; name_mapping = name_mapping)
    time_series = IS.get_time_series(IS.SingleTimeSeries, component2, name2b)
    @test time_series isa IS.SingleTimeSeries
    @test IS.get_initial_time(time_series) == initial_time2
    @test IS.get_name(time_series) == name2b
    @test_throws ArgumentError IS.get_time_series(IS.SingleTimeSeries, component2, name2a)
end

@testset "Test component-time_series being added to multiple systems" begin
    sys1 = IS.SystemData()
    sys2 = IS.SystemData()
    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(sys1, component)

    dates = create_dates("2020-01-01T00:00:00", Dates.Hour(1), "2020-01-01T23:00:00")
    data = collect(1:24)
    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    name = "val"
    ts = IS.SingleTimeSeries(name, ta)
    IS.add_time_series!(sys1, component, ts)

    @test_throws ArgumentError IS.add_component!(sys1, component)
end

@testset "Summarize time_series" begin
    data = create_system_data(; with_time_series = true)
    summary(devnull, data.time_series_params)
end

@testset "Test time_series forwarding methods" begin
    data = create_system_data(; with_time_series = true)
    time_series = get_all_time_series(data)[1]

    # Iteration
    size = 24
    @test length(time_series) == size
    i = 0
    for x in time_series
        i += 1
    end
    @test i == size

    # Indexing
    @test length(time_series[1:16]) == 16

    # when
    fcast = IS.when(time_series, TimeSeries.hour, 3)
    @test length(fcast) == 1
end

@testset "Test time_series head" begin
    data = create_system_data(; with_time_series = true)
    time_series = get_all_time_series(data)[1]
    fcast = IS.head(time_series)
    # head returns a length of 6 by default, but don't hard-code that.
    @test length(fcast) < length(time_series)

    fcast = IS.head(time_series, 10)
    @test length(fcast) == 10
end

@testset "Test time_series tail" begin
    data = create_system_data(; with_time_series = true)
    time_series = get_all_time_series(data)[1]
    fcast = IS.tail(time_series)
    # tail returns a length of 6 by default, but don't hard-code that.
    @test length(fcast) < length(time_series)

    fcast = IS.head(time_series, 10)
    @test length(fcast) == 10
end

@testset "Test time_series from" begin
    data = create_system_data(; with_time_series = true)
    time_series = get_all_time_series(data)[1]
    start_time = Dates.DateTime(Dates.today()) + Dates.Hour(3)
    fcast = IS.from(time_series, start_time)
    @test length(fcast) == 21
    @test TimeSeries.timestamp(IS.get_data(fcast))[1] == start_time
end

@testset "Test time_series from" begin
    data = create_system_data(; with_time_series = true)
    time_series = get_all_time_series(data)[1]
    for end_time in (
        Dates.DateTime(Dates.today()) + Dates.Hour(15),
        Dates.DateTime(Dates.today()) + Dates.Hour(15) + Dates.Minute(5),
    )
        fcast = IS.to(time_series, end_time)
        @test length(fcast) == 16
        @test TimeSeries.timestamp(IS.get_data(fcast))[end] <= end_time
    end
end

# TODO 1.0: Scenarios are broken
#=
@testset "Test Scenarios time_series" begin
    sys = IS.SystemData()
    name = "Component1"
    name = "val"
    component = IS.TestComponent(name, 5)
    IS.add_component!(sys, component)

    initial_timestamp = Dates.DateTime("2020-01-01T00:00:00")
    horizon = 24
    resolution = Dates.Hour(1)
    scenario_count = 2
    data = SortedDict(initial_timestamp => ones(horizon, scenario_count))
    time_series = IS.Scenarios(
        name = name,
        initial_timestamp = initial_timestamp,
        horizon = horizon,
        resolution = resolution,
        scenario_count = scenario_count,
        data = data,
    )
    fdata = IS.get_data(time_series)
    @test length(TimeSeries.colnames(fdata)) == 2
    @test TimeSeries.timestamp(ta) == TimeSeries.timestamp(fdata)
    @test TimeSeries.values(ta) == TimeSeries.values(fdata)

    IS.add_time_series!(sys, component, time_series)
    time_series2 = IS.get_time_series(IS.Scenarios, component, name)
    @test time_series2 isa IS.Scenarios
    fdata2 = IS.get_data(time_series2)
    @test length(TimeSeries.colnames(fdata2)) == 2
    @test TimeSeries.timestamp(ta) == TimeSeries.timestamp(fdata2)
    @test TimeSeries.values(ta) == TimeSeries.values(fdata2)

    no_time_series = 3
    time_series3 =
        IS.get_time_series(IS.Scenarios, component, name, no_time_series)
    @test time_series3 isa IS.Scenarios
    fdata3 = IS.get_data(time_series3)
    @test length(TimeSeries.colnames(fdata3)) == 2
    @test TimeSeries.timestamp(ta)[1:no_time_series] == TimeSeries.timestamp(fdata3)
    @test TimeSeries.values(ta)[1:no_time_series, :] == TimeSeries.values(fdata3)
end
=#

@testset "Add time_series to unsupported struct" begin
    struct TestComponentNoTimeSeries <: IS.InfrastructureSystemsComponent
        name::AbstractString
        internal::IS.InfrastructureSystemsInternal
    end

    function TestComponentNoTimeSeries(name)
        return TestComponentNoTimeSeries(name, IS.InfrastructureSystemsInternal())
    end

    sys = IS.SystemData()
    name = "component"
    component = TestComponentNoTimeSeries(name)
    IS.add_component!(sys, component)
    dates = create_dates("2020-01-01T00:00:00", Dates.Hour(1), "2020-01-01T23:00:00")
    ta = TimeSeries.TimeArray(dates, collect(1:24), [IS.get_name(component)])
    time_series = IS.SingleTimeSeries(name = "val", data = ta)
    @test_throws ArgumentError IS.add_time_series!(sys, component, time_series)
end

@testset "Test system time series parameters" begin
    sys = IS.SystemData()
    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(sys, component)

    @test IS.get_forecast_initial_times(sys) == []

    resolution = Dates.Hour(1)
    initial_time = Dates.DateTime("2020-09-01")
    second_time = initial_time + resolution
    name = "test"
    horizon = 24
    data = SortedDict(initial_time => ones(horizon), second_time => ones(horizon))

    forecast = IS.Deterministic(
        data = data,
        name = name,
        initial_timestamp = initial_time,
        horizon = horizon,
        resolution = resolution,
    )
    IS.add_time_series!(sys, component, forecast)

    @test IS.get_time_series_resolution(sys) == resolution
    @test IS.get_forecast_window_count(sys) == 2
    @test IS.get_forecast_horizon(sys) == horizon
    @test IS.get_forecast_initial_timestamp(sys) == initial_time
    @test IS.get_forecast_interval(sys) == second_time - initial_time
    @test IS.get_forecast_initial_times(sys) == [initial_time, second_time]
    @test IS.get_initial_times(forecast) == IS.get_forecast_initial_times(sys)
    @test Dates.Hour(IS.get_forecast_total_period(sys)) ==
          Dates.Hour(second_time - initial_time) + Dates.Hour(resolution * horizon)
    @test IS.get_forecast_total_period(sys) == IS.get_total_period(forecast)
end

@testset "Test conflicting time series parameters" begin
    sys = IS.SystemData()
    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(sys, component)

    # Set baseline parameters for the rest of the tests.
    resolution = Dates.Hour(1)
    initial_time = Dates.DateTime("2020-09-01")
    second_time = initial_time + resolution
    name = "test"
    horizon = 24
    data = SortedDict(initial_time => ones(horizon), second_time => ones(horizon))

    forecast = IS.Deterministic(
        data = data,
        name = name,
        initial_timestamp = initial_time,
        horizon = horizon,
        resolution = resolution,
    )
    IS.add_time_series!(sys, component, forecast)

    # Conflicting initial time
    initial_time2 = Dates.DateTime("2020-09-02")
    name = "test2"
    data = SortedDict(initial_time2 => ones(horizon), second_time => ones(horizon))

    forecast = IS.Deterministic(
        data = data,
        name = name,
        initial_timestamp = initial_time2,
        horizon = horizon,
        resolution = resolution,
    )
    @test_throws IS.ConflictingInputsError IS.add_time_series!(sys, component, forecast)

    # Conflicting resolution
    resolution2 = Dates.Minute(5)
    name = "test2"
    data = SortedDict(initial_time => ones(horizon), second_time => ones(horizon))

    forecast = IS.Deterministic(
        data = data,
        name = name,
        initial_timestamp = initial_time2,
        horizon = horizon,
        resolution = resolution2,
    )
    @test_throws IS.ConflictingInputsError IS.add_time_series!(sys, component, forecast)

    # Conflicting horizon
    name = "test2"
    horizon2 = 23
    data = SortedDict(initial_time => ones(horizon2), second_time => ones(horizon2))

    forecast = IS.Deterministic(
        data = data,
        name = name,
        initial_timestamp = initial_time2,
        horizon = horizon2,
        resolution = resolution,
    )
    @test_throws IS.ConflictingInputsError IS.add_time_series!(sys, component, forecast)

    # Conflicting count
    name = "test3"
    third_time = second_time + resolution
    data = SortedDict(
        initial_time => ones(horizon),
        second_time => ones(horizon),
        third_time => ones(horizon),
    )

    forecast = IS.Deterministic(
        data = data,
        name = name,
        initial_timestamp = initial_time,
        horizon = horizon,
        resolution = resolution,
    )
    @test_throws IS.ConflictingInputsError IS.add_time_series!(sys, component, forecast)
end
