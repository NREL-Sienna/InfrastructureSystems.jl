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
    initial_time = Dates.DateTime("2020-09-01")
    resolution = Dates.Hour(1)
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
    # This still returns a forecast object. Requires update of the interfaces
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

    # TODO 1.0: same or not?
    #@test IS.get_uuid(forecast) == IS.get_uuid(var1)
    #@test IS.get_uuid(forecast) == IS.get_uuid(var2)
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

    data = IS.SystemData()
    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(data, component)
    @test !IS.has_time_series(component)
    file = joinpath(FORECASTS_DIR, "ForecastPointers.json")
    IS.add_time_series_from_file_metadata!(sys, IS.InfrastructureSystemsComponent, file)
    @test IS.has_time_series(component)
end
