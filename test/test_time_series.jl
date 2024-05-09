@testset "Test add forecasts on the fly from dict" begin
    sys = IS.SystemData()
    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(sys, component)

    initial_time = Dates.DateTime("2020-09-01")
    resolution = Dates.Hour(1)

    other_time = initial_time + resolution
    name = "test"
    horizon = 24
    data = SortedDict(initial_time => ones(horizon), other_time => ones(horizon))

    forecast = IS.Deterministic(; data = data, name = name, resolution = resolution)
    key = IS.add_time_series!(sys, component, forecast)
    @test key isa IS.ForecastKey
    @test key.name == name
    @test key.horizon == horizon
    @test key.resolution == resolution
    var1 =
        IS.get_time_series(IS.Deterministic, component, name; start_time = initial_time)
    @test length(var1) == 2
    @test IS.get_horizon(var1) == horizon
    @test IS.get_initial_timestamp(var1) == initial_time

    var2 = IS.get_time_series(
        IS.Deterministic,
        component,
        name;
        start_time = initial_time,
        count = 2,
    )
    @test length(var2) == 2

    var3 =
        IS.get_time_series(IS.Deterministic, component, name; start_time = other_time)
    @test length(var2) == 2
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
    @test_throws ArgumentError IS.get_time_series(
        IS.Deterministic,
        component,
        name;
        start_time = other_time + resolution,
    )

    count = IS.get_count(var2)
    @test count == 2

    window1 = IS.get_window(var2, initial_time)
    @test window1 isa TimeSeries.TimeArray
    @test TimeSeries.timestamp(window1)[1] == initial_time
    window2 = IS.get_window(var2, other_time)
    @test window2 isa TimeSeries.TimeArray
    @test TimeSeries.timestamp(window2)[1] == other_time

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
    data = Dict(initial_time => ones(horizon), other_time => ones(horizon))
    sys = IS.SystemData()
    component_name = "Component1"
    component = IS.TestComponent(component_name, 5)
    IS.add_component!(sys, component)
    forecast = IS.Deterministic(name, data, resolution)
    @test IS.get_initial_timestamp(forecast) == initial_time
    IS.add_time_series!(sys, component, forecast)
    @test IS.has_time_series(component)

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

@testset "Test add Deterministic Cost Timeseries" begin
    initial_time = Dates.DateTime("2020-09-01")
    resolution = Dates.Hour(1)
    other_time = initial_time + resolution
    name = "test"
    horizon = 24
    linear_cost = repeat([IS.LinearFunctionData(3.14, 1.23)], 24)
    data_linear = SortedDict(initial_time => linear_cost, other_time => linear_cost)
    polynomial_cost = repeat([IS.QuadraticFunctionData(999.0, 1.0, 0.5)], 24)
    data_polynomial =
        SortedDict(initial_time => polynomial_cost, other_time => polynomial_cost)
    pwl_cost = repeat([IS.PiecewiseLinearData(repeat([(999.0, 1.0)], 5))], 24)
    data_pwl = SortedDict(initial_time => pwl_cost, other_time => pwl_cost)
    for d in [data_linear, data_polynomial, data_pwl]
        @testset "Add deterministic from $(typeof(d))" begin
            sys = IS.SystemData()
            component_name = "Component1"
            component = IS.TestComponent(component_name, 5)
            IS.add_component!(sys, component)
            forecast = IS.Deterministic(name, d, resolution)
            @test IS.get_initial_timestamp(forecast) == initial_time
            IS.add_time_series!(sys, component, forecast)
            @test IS.has_time_series(component)
        end
    end

    data_ts_linear = Dict(
        initial_time => TimeSeries.TimeArray(
            range(initial_time; length = horizon, step = resolution),
            linear_cost,
        ),
        other_time => TimeSeries.TimeArray(
            range(other_time; length = horizon, step = resolution),
            linear_cost,
        ),
    )
    data_ts_polynomial = Dict(
        initial_time => TimeSeries.TimeArray(
            range(initial_time; length = horizon, step = resolution),
            polynomial_cost,
        ),
        other_time => TimeSeries.TimeArray(
            range(other_time; length = horizon, step = resolution),
            polynomial_cost,
        ),
    )
    data_ts_pwl = Dict(
        initial_time => TimeSeries.TimeArray(
            range(initial_time; length = horizon, step = resolution),
            pwl_cost,
        ),
        other_time => TimeSeries.TimeArray(
            range(other_time; length = horizon, step = resolution),
            pwl_cost,
        ),
    )
    for d in [data_ts_linear, data_ts_polynomial, data_ts_pwl]
        @testset "Add deterministic from $(typeof(d))" begin
            sys = IS.SystemData()
            component_name = "Component1"
            component = IS.TestComponent(component_name, 5)
            IS.add_component!(sys, component)
            forecast = IS.Deterministic(name, d)
            @test IS.get_initial_timestamp(forecast) == initial_time
            IS.add_time_series!(sys, component, forecast)
            @test IS.has_time_series(component)
        end
    end
end

@testset "Test add Probabilistic" begin
    initial_time = Dates.DateTime("2020-09-01")
    resolution = Dates.Hour(1)
    other_time = initial_time + resolution
    name = "test"
    horizon = 24
    data_vec = Dict(initial_time => ones(horizon, 99), other_time => ones(horizon, 99))
    sys = IS.SystemData()
    component_name = "Component1"
    component = IS.TestComponent(component_name, 5)
    IS.add_component!(sys, component)
    forecast = IS.Probabilistic(name, data_vec, ones(99), resolution)
    IS.add_time_series!(sys, component, forecast)
    @test IS.has_time_series(component)
    @test IS.get_initial_timestamp(forecast) == initial_time
    forecast_retrieved =
        IS.get_time_series(
            IS.Probabilistic,
            component,
            "test";
            start_time = initial_time,
        )
    @test IS.get_initial_timestamp(forecast_retrieved) == initial_time

    data_ts = Dict(
        initial_time => TimeSeries.TimeArray(
            range(initial_time; length = horizon, step = resolution),
            ones(horizon, 99),
        ),
        other_time => TimeSeries.TimeArray(
            range(other_time; length = horizon, step = resolution),
            ones(horizon, 99),
        ),
    )
    sys = IS.SystemData()
    component_name = "Component1"
    component = IS.TestComponent(component_name, 5)
    IS.add_component!(sys, component)
    forecast = IS.Probabilistic(name, data_ts, ones(99))
    IS.add_time_series!(sys, component, forecast)
    @test IS.has_time_series(component)
    @test IS.get_initial_timestamp(forecast) == initial_time
end

@testset "Test add Scenarios" begin
    initial_time = Dates.DateTime("2020-09-01")
    resolution = Dates.Hour(1)
    other_time = initial_time + resolution
    name = "test"
    horizon = 24
    data_vec = Dict(initial_time => ones(horizon, 99), other_time => ones(horizon, 99))
    sys = IS.SystemData()
    component_name = "Component1"
    component = IS.TestComponent(component_name, 5)
    IS.add_component!(sys, component)
    forecast = IS.Scenarios(name, data_vec, resolution)
    IS.add_time_series!(sys, component, forecast)
    @test IS.has_time_series(component)
    @test IS.get_initial_timestamp(forecast) == initial_time
    forecast_retrieved =
        IS.get_time_series(IS.Scenarios, component, "test"; start_time = initial_time)
    @test IS.get_initial_timestamp(forecast_retrieved) == initial_time

    data_ts = Dict(
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
    forecast = IS.Scenarios(name, data_ts)
    IS.add_time_series!(sys, component, forecast)
    @test IS.has_time_series(component)
    @test IS.get_initial_timestamp(forecast) == initial_time
end

function _test_add_single_time_series_helper(component, initial_time)
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
end

@testset "Test add SingleTimeSeries" begin
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
    ts_name = "test_c"
    data = IS.SingleTimeSeries(; data = data, name = ts_name)
    IS.add_time_series!(sys, component, data)

    _test_add_single_time_series_helper(component, initial_time)

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

    # As of PSY 4.0, multiple resolutions are supported.
    data = TimeSeries.TimeArray(
        range(initial_time; length = 365, step = Dates.Minute(5)),
        ones(365),
    )
    data = IS.SingleTimeSeries(; data = data, name = "test_d")
    IS.add_time_series!(sys, component, data)
end

@testset "Test add SingleTimeSeries with features" begin
    sys = IS.SystemData()
    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(sys, component)

    initial_time = Dates.DateTime("2020-09-01")
    resolution = Dates.Hour(1)

    data = TimeSeries.TimeArray(
        range(initial_time; length = 365, step = resolution),
        rand(365),
    )
    ts_name = "test_c"
    ts = IS.SingleTimeSeries(; data = data, name = ts_name)
    IS.add_time_series!(sys, component, ts; scenario = "low", model_year = "2030")
    # get_time_series with partial query works if there is only 1.
    @test IS.get_time_series(IS.SingleTimeSeries, component, ts_name).data == data
    @test IS.get_time_series(
        IS.SingleTimeSeries,
        component,
        ts_name;
        scenario = "low",
    ).data == data
    @test IS.get_time_series(
        IS.SingleTimeSeries,
        component,
        ts_name;
        scenario = "low",
        model_year = "2030",
    ).data == data
    @test IS.get_time_series_values(
        IS.SingleTimeSeries,
        component,
        ts_name;
        scenario = "low",
        model_year = "2030",
    ) == TimeSeries.values(data)
    @test IS.get_time_series_timestamps(
        IS.SingleTimeSeries,
        component,
        ts_name;
        scenario = "low",
        model_year = "2030",
    ) == TimeSeries.timestamp(data)

    IS.add_time_series!(sys, component, ts; scenario = "high", model_year = "2030")
    IS.add_time_series!(sys, component, ts; scenario = "low", model_year = "2035")
    IS.add_time_series!(sys, component, ts; scenario = "high", model_year = "2035")

    @test_throws ArgumentError IS.get_time_series(
        IS.SingleTimeSeries,
        component,
        ts_name,
    )
    @test_throws ArgumentError IS.get_time_series(
        IS.SingleTimeSeries,
        component,
        ts_name,
        scenario = "low",
    )
    @test IS.get_time_series(
        IS.SingleTimeSeries,
        component,
        ts_name;
        scenario = "low",
        model_year = "2035",
    ) isa IS.SingleTimeSeries
    @test IS.has_time_series(component, IS.SingleTimeSeries)
    @test IS.has_time_series(component, IS.SingleTimeSeries, ts_name)
    @test IS.has_time_series(component, IS.SingleTimeSeries, ts_name, scenario = "low")
    @test IS.has_time_series(
        component,
        IS.SingleTimeSeries,
        ts_name,
        model_year = "2030",
        scenario = "low",
    )
    @test IS.has_time_series(
        component,
        IS.SingleTimeSeries,
        ts_name,
        model_year = "2030",
        scenario = "low",
    )
    @test !IS.has_time_series(
        component,
        IS.SingleTimeSeries,
        ts_name;
        model_year = "2060",
        scenario = "low",
    )
    @test length(IS.get_time_series_keys(component)) == 4
    @test IS.get_time_series_type(IS.get_time_series_keys(component)[1]) ===
          IS.SingleTimeSeries
    @test Tables.rowtable(
        IS.sql(
            sys.time_series_manager.metadata_store,
            "SELECT COUNT(*) AS count FROM $(IS.METADATA_TABLE_NAME)",
        ),
    )[1].count == 4
    for key in IS.get_time_series_keys(component)
        @test IS.get_data(IS.get_time_series(component, key)) == data
    end
    IS.remove_time_series!(sys, IS.SingleTimeSeries)
    @test isempty(IS.get_time_series_keys(component))
end

@testset "Test add with features with mixed types" begin
    sys = IS.SystemData()
    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(sys, component)

    initial_time = Dates.DateTime("2020-09-01")
    resolution = Dates.Hour(1)

    data = TimeSeries.TimeArray(
        range(initial_time; length = 365, step = resolution),
        rand(365),
    )
    ts_name = "test"
    ts = IS.SingleTimeSeries(; data = data, name = ts_name)
    IS.add_time_series!(sys, component, ts; scenario = "low", model_year = "2030")
    @test IS.has_time_series(
        component,
        IS.SingleTimeSeries,
        ts_name;
        scenario = "low",
        model_year = "2030",
    )
    @test !IS.has_time_series(
        component,
        IS.SingleTimeSeries,
        ts_name;
        scenario = "low",
        model_year = 2030,
    )
    IS.add_time_series!(sys, component, ts; scenario = "low", model_year = 2030)
    @test IS.has_time_series(
        component,
        IS.SingleTimeSeries,
        ts_name;
        scenario = "low",
        model_year = 2030,
    )
    IS.add_time_series!(sys, component, ts; scenario = "low", model_year = 2035)
    @test IS.has_time_series(
        component,
        IS.SingleTimeSeries,
        ts_name;
        scenario = "low",
        model_year = 2035,
    )
    @test !IS.has_time_series(
        component,
        IS.SingleTimeSeries,
        ts_name;
        scenario = "low",
        model_year = "2035",
    )
    IS.add_time_series!(sys, component, ts; scenario = "low", model_year = "2035")
    @test IS.has_time_series(
        component,
        IS.SingleTimeSeries,
        ts_name;
        scenario = "low",
        model_year = "2035",
    )
    IS.add_time_series!(sys, component, ts; scenario = "low", some_condition = true)
    @test IS.has_time_series(component, IS.SingleTimeSeries, ts_name; some_condition = true)
    @test !IS.has_time_series(
        component,
        IS.SingleTimeSeries,
        ts_name;
        some_condition = "true",
    )
    IS.add_time_series!(sys, component, ts; scenario = "low", some_condition = "false")
    @test !IS.has_time_series(
        component,
        IS.SingleTimeSeries,
        ts_name;
        some_condition = false,
    )
    IS.add_time_series!(sys, component, ts; scenario = "low", some_condition = false)
    @test IS.has_time_series(
        component,
        IS.SingleTimeSeries,
        ts_name;
        some_condition = false,
    )
    @test_throws MethodError IS.add_time_series!(
        sys,
        component,
        ts;
        scenario = Dict("key" => "val"),
    )
    # Duplicate features in different order.
    @test_throws ArgumentError IS.add_time_series!(
        sys,
        component,
        ts;
        scenario = "low",
        model_year = "2035",
    )
    @test_throws ArgumentError IS.add_time_series!(
        sys,
        component,
        ts;
        model_year = "2035",
        scenario = "low",
    )
end

@testset "Test add Deterministic with features" begin
    sys = IS.SystemData()
    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(sys, component)

    initial_time = Dates.DateTime("2020-09-01")
    resolution = Dates.Hour(1)

    other_time = initial_time + resolution
    ts_name = "test"
    horizon = 24
    data = SortedDict(initial_time => rand(horizon), other_time => rand(horizon))

    forecast = IS.Deterministic(; data = data, name = ts_name, resolution = resolution)
    IS.add_time_series!(sys, component, forecast; scenario = "low", model_year = "2030")
    IS.add_time_series!(
        sys,
        component,
        forecast;
        scenario = "high",
        model_year = "2030",
    )
    IS.add_time_series!(sys, component, forecast; scenario = "low", model_year = "2035")
    IS.add_time_series!(
        sys,
        component,
        forecast;
        scenario = "high",
        model_year = "2035",
    )

    @test_throws ArgumentError IS.get_time_series(
        IS.Deterministic,
        component,
        ts_name,
    )
    @test_throws ArgumentError IS.get_time_series(
        IS.Deterministic,
        component,
        ts_name,
        scenario = "low",
    )
    @test IS.get_time_series(
        IS.Deterministic,
        component,
        ts_name;
        scenario = "low",
        model_year = "2035",
    ) isa IS.Deterministic
    @test length(IS.get_time_series_metadata(component)) == 4
    @test length(
        IS.get_time_series_metadata(component; time_series_type = IS.Deterministic),
    ) == 4
    @test length(
        IS.get_time_series_metadata(
            component;
            time_series_type = IS.Deterministic,
            name = ts_name,
        ),
    ) == 4
    @test length(
        IS.get_time_series_metadata(
            component;
            time_series_type = IS.Deterministic,
            name = ts_name,
            scenario = "low",
        ),
    ) == 2
    @test length(
        IS.get_time_series_metadata(
            component;
            time_series_type = IS.Deterministic,
            name = ts_name,
            scenario = "low",
            model_year = "2035",
        ),
    ) == 1
    @test IS.get_time_series_metadata(
        component;
        time_series_type = IS.Deterministic,
        name = ts_name,
        scenario = "low",
        model_year = "2035",
    )[1].features["model_year"] == "2035"
    @test length(IS.get_time_series_keys(component)) == 4
    @test IS.get_time_series_type(IS.get_time_series_keys(component)[1]) ===
          IS.Deterministic

    IS.remove_time_series!(sys, IS.Deterministic, component, ts_name; scenario = "low")
    @test length(
        IS.get_time_series_metadata(component; time_series_type = IS.Deterministic),
    ) == 2
    for metadata in
        IS.get_time_series_metadata(component; time_series_type = IS.Deterministic)
        @test metadata.features["scenario"] == "high"
    end
    IS.remove_time_series!(sys, IS.Deterministic, component, ts_name)
    @test isempty(IS.get_time_series_metadata(component))
end

@testset "Test Deterministic with a wrapped SingleTimeSeries" begin
    for in_memory in (true, false)
        sys = IS.SystemData(; time_series_in_memory = in_memory)
        component = IS.TestComponent("Component1", 5)
        IS.add_component!(sys, component)

        resolution = Dates.Minute(5)
        dates = create_dates("2020-01-01T00:00:00", resolution, "2020-01-01T23:05:00")
        data = collect(1:length(dates))
        ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
        name = "val"
        ts = IS.SingleTimeSeries(name, ta)
        IS.add_time_series!(sys, component, ts)
        horizon = 6
        verify_show(sys)

        # Create a Deterministic as a bystander.
        forecast_count = 46
        fdata = SortedDict{Dates.DateTime, Vector{Float64}}()
        for i in 1:forecast_count
            fdata[dates[i]] = ones(horizon)
        end
        bystander =
            IS.Deterministic(;
                data = fdata,
                name = "bystander",
                resolution = resolution,
            )
        IS.add_time_series!(sys, component, bystander)

        counts = IS.get_time_series_counts(sys)
        @test counts.components_with_time_series == 1
        @test counts.supplemental_attributes_with_time_series == 0
        @test counts.static_time_series_count == 1
        @test counts.forecast_count == 1

        # This interval is greater than the max possible.
        @test_throws IS.ConflictingInputsError IS.transform_single_time_series!(
            sys,
            IS.DeterministicSingleTimeSeries,
            horizon,
            Dates.Hour(100),
        )
        interval = Dates.Minute(30)
        IS.transform_single_time_series!(
            sys,
            IS.DeterministicSingleTimeSeries,
            horizon,
            interval,
        )
        verify_show(sys)

        counts = IS.get_time_series_counts(sys)
        @test counts.components_with_time_series == 1
        @test counts.supplemental_attributes_with_time_series == 0
        @test counts.static_time_series_count == 1
        @test counts.forecast_count == 2

        # The original should still be readable.
        single_vals = IS.get_time_series_values(IS.SingleTimeSeries, component, name)
        @test single_vals == data

        @test IS.get_time_series(IS.Deterministic, component, "bystander") isa
              IS.Deterministic

        # Get the transformed forecast.
        forecast = IS.get_time_series(IS.DeterministicSingleTimeSeries, component, name)
        @test IS.get_interval(forecast) == interval
        window = IS.get_window(forecast, dates[1])
        @test window isa TimeSeries.TimeArray
        @test TimeSeries.timestamp(window) == TimeSeries.timestamp(ta[1:horizon])
        @test TimeSeries.values(window) == TimeSeries.values(ta[1:horizon])

        windows = collect(IS.iterate_windows(forecast))
        # Note that there is an extra 5 minutes being truncated.
        exp_length = Dates.Hour(dates[end - 1] - first(dates)).value * 2
        @test length(windows) == exp_length
        last_initial_time = dates[end - 1] - interval
        last_it_index = length(dates) - 1 - Int(Dates.Minute(interval) / resolution)
        @test last_initial_time == dates[last_it_index]
        last_val_index = last_it_index + horizon - 1
        @test TimeSeries.values(windows[exp_length]) ==
              data[last_it_index:last_val_index]

        # Do the same thing but pass Deterministic instead.
        forecast = IS.get_time_series(IS.Deterministic, component, name)
        window = IS.get_window(forecast, dates[1])
        @test window isa TimeSeries.TimeArray
        @test TimeSeries.timestamp(window) == TimeSeries.timestamp(ta[1:horizon])
        @test TimeSeries.values(window) == TimeSeries.values(ta[1:horizon])

        # Verify that get_time_series_multiple works with these types.
        forecasts = collect(IS.get_time_series_multiple(sys))
        @test length(forecasts) == 3
        forecasts = collect(IS.get_time_series_multiple(sys; type = IS.Deterministic))
        @test length(forecasts) == 1
        forecasts =
            collect(
                IS.get_time_series_multiple(
                    sys;
                    type = IS.DeterministicSingleTimeSeries,
                ),
            )
        @test length(forecasts) == 1
        @test forecasts[1] isa IS.DeterministicSingleTimeSeries

        # Must start on a window.
        @test_throws ArgumentError IS.get_time_series(
            IS.Deterministic,
            component,
            name;
            start_time = dates[2],
        )
        # Must pass a full horizon.
        @test_throws ArgumentError IS.get_time_series(
            IS.Deterministic,
            component,
            name;
            len = horizon - 1,
        )
        # Already stored.
        @test IS.transform_single_time_series!(
            sys,
            IS.DeterministicSingleTimeSeries,
            horizon,
            interval,
        ) === nothing
        # Bad horizon
        @test_throws IS.ConflictingInputsError IS.transform_single_time_series!(
            sys,
            IS.DeterministicSingleTimeSeries,
            1000, # horizon is longer than single time series
            interval,
        )

        # The next test is not compatible with the bystander.
        IS.remove_time_series!(sys, IS.Deterministic, component, "bystander")

        # Good but different horizon
        @test IS.transform_single_time_series!(
            sys,
            IS.DeterministicSingleTimeSeries,
            12,
            interval,
        ) === nothing

        # Good but different interval
        @test IS.transform_single_time_series!(
            sys,
            IS.DeterministicSingleTimeSeries,
            2,
            Dates.Minute(10),
        ) === nothing

        # Bad interval
        @test_throws IS.ConflictingInputsError IS.transform_single_time_series!(
            sys,
            IS.DeterministicSingleTimeSeries,
            horizon,
            resolution * (horizon + 1),
        )

        # Multiple resolutions is not supported yet
        resolution2 = Dates.Hour(1)
        dates = create_dates("2020-01-01T00:00:00", resolution2, "2020-01-02T00:00:00")
        data = collect(1:length(dates))
        ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
        name = "val2"
        ts = IS.SingleTimeSeries(name, ta)
        IS.add_time_series!(sys, component, ts)
        horizon = 24
        @test_throws IS.ConflictingInputsError IS.transform_single_time_series!(
            sys,
            IS.DeterministicSingleTimeSeries,
            horizon,
            resolution2 * (horizon + 1),
        )

        # Ensure that attempted removal of nonexistent types works fine
        counts = IS.get_time_series_counts(sys)
        IS.remove_time_series!(sys, IS.Probabilistic)
        @test counts === IS.get_time_series_counts(sys)
    end
end

@testset "Test Deterministic with a wrapped SingleTimeSeries different offsets" begin
    for in_memory in (true, false)
        sys = IS.SystemData(; time_series_in_memory = in_memory)
        component = IS.TestComponent("Component1", 5)
        IS.add_component!(sys, component)

        resolution = Dates.Hour(1)
        dates1 = create_dates("2020-01-01T00:00:00", resolution, "2020-01-02T00:00:00")
        dates2 = create_dates("2020-01-01T00:00:00", resolution, "2020-01-01T23:00:00")
        data1 = collect(1:length(dates1))
        data2 = collect(1:length(dates2))
        ta1 = TimeSeries.TimeArray(dates1, data1, [IS.get_name(component)])
        ta2 = TimeSeries.TimeArray(dates2, data2, [IS.get_name(component)])
        name1 = "val1"
        name2 = "val2"
        ts1 = IS.SingleTimeSeries(name1, ta1)
        ts2 = IS.SingleTimeSeries(name2, ta2)
        IS.add_time_series!(sys, component, ts1)
        IS.add_time_series!(sys, component, ts2)

        horizon = 1
        interval = Dates.Hour(1)
        @test_throws IS.ConflictingInputsError IS.transform_single_time_series!(
            sys,
            IS.DeterministicSingleTimeSeries,
            horizon,
            interval,
        )
    end
end

@testset "Test SingleTimeSeries transform with multiple forecasts per component" begin
    sys = IS.SystemData(; time_series_in_memory = true)
    component = IS.TestComponent("Component1", 5)
    IS.add_component!(sys, component)

    resolution = Dates.Minute(5)
    dates = create_dates("2020-01-01T00:00:00", resolution, "2020-01-01T23:05:00")
    data = collect(1:length(dates))
    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    ts_names = []
    for i in 1:10
        name = string(UUIDs.uuid4())
        ts = IS.SingleTimeSeries(name, ta)
        IS.add_time_series!(sys, component, ts)
        push!(ts_names, name)
    end
    horizon = 6

    interval = Dates.Minute(30)
    IS.transform_single_time_series!(
        sys,
        IS.DeterministicSingleTimeSeries,
        horizon,
        interval,
    )

    for name in ts_names
        forecast = IS.get_time_series(IS.Deterministic, component, name)
        @test forecast isa IS.DeterministicSingleTimeSeries
    end
end

@testset "Test SingleTimeSeries transform deletions" begin
    for in_memory in (true, false)
        sys = IS.SystemData(; time_series_in_memory = in_memory)
        component = IS.TestComponent("Component1", 5)
        IS.add_component!(sys, component)

        resolution = Dates.Minute(5)
        dates = create_dates("2020-01-01T00:00:00", resolution, "2020-01-01T23:05:00")
        data = collect(1:length(dates))
        ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
        name = "val"
        ts = IS.SingleTimeSeries(name, ta)
        IS.add_time_series!(sys, component, ts)
        horizon = 6

        interval = Dates.Minute(30)
        IS.transform_single_time_series!(
            sys,
            IS.DeterministicSingleTimeSeries,
            horizon,
            interval,
        )

        # Ensure that deleting one doesn't delete the other.
        if in_memory
            IS.remove_time_series!(sys, IS.Deterministic, component, name)
            @test IS.get_time_series(IS.SingleTimeSeries, component, name) isa
                  IS.SingleTimeSeries
        else
            IS.remove_time_series!(sys, IS.SingleTimeSeries, component, name)
            @test IS.get_time_series(IS.Deterministic, component, name) isa
                  IS.DeterministicSingleTimeSeries
        end
    end
end

@testset "Test DeterministicSingleTimeSeries with single window" begin
    sys = IS.SystemData(; time_series_in_memory = true)
    component = IS.TestComponent("Component1", 5)
    IS.add_component!(sys, component)

    resolution = Dates.Hour(1)
    horizon = 24
    dates = collect(
        range(
            Dates.DateTime("2020-01-01T00:00:00");
            length = horizon,
            step = resolution,
        ),
    )
    data = collect(1:horizon)
    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    name = "val"
    ts = IS.SingleTimeSeries(name, ta)
    IS.add_time_series!(sys, component, ts)

    interval = Dates.Hour(horizon)
    IS.transform_single_time_series!(
        sys,
        IS.DeterministicSingleTimeSeries,
        horizon,
        interval,
    )

    initial_times = collect(IS.get_forecast_initial_times(sys))
    @test initial_times == [Dates.DateTime("2020-01-01T00:00:00")]
    forecast = IS.get_time_series(IS.DeterministicSingleTimeSeries, component, name)
    @test IS.get_interval(forecast) == Dates.Second(0)
end

@testset "Test DeterministicSingleTimeSeries with interval = resolution" begin
    sys = IS.SystemData(; time_series_in_memory = true)
    component = IS.TestComponent("Component1", 5)
    IS.add_component!(sys, component)

    resolution = Dates.Hour(1)
    horizon = 24
    dates = collect(
        range(
            Dates.DateTime("2020-01-01T00:00:00");
            length = horizon,
            step = resolution,
        ),
    )
    data = collect(1:horizon)
    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    name = "val"
    ts = IS.SingleTimeSeries(name, ta)
    IS.add_time_series!(sys, component, ts)

    interval = resolution
    IS.transform_single_time_series!(
        sys,
        IS.DeterministicSingleTimeSeries,
        horizon,
        interval,
    )

    initial_times = collect(IS.get_forecast_initial_times(sys))
    @test initial_times == [Dates.DateTime("2020-01-01T00:00:00")]
    forecast = IS.get_time_series(IS.DeterministicSingleTimeSeries, component, name)
    @test IS.get_interval(forecast) == interval
end

@testset "Test component removal with DeterministicSingleTimeSeries" begin
    sys = IS.SystemData()
    component = IS.TestComponent("Component1", 5)
    IS.add_component!(sys, component)

    resolution = Dates.Minute(5)
    dates = create_dates("2020-01-01T00:00:00", resolution, "2020-01-01T23:00:00")
    data = collect(1:length(dates))
    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    name = "val"
    ts = IS.SingleTimeSeries(name, ta)
    IS.add_time_series!(sys, component, ts)
    horizon = 6
    interval = Dates.Minute(10)
    IS.transform_single_time_series!(
        sys,
        IS.DeterministicSingleTimeSeries,
        horizon,
        interval,
    )
    IS.remove_component!(sys, component)
    @test length(IS.get_components(IS.TestComponent, sys)) == 0
end

function _test_add_single_time_series_type(test_value, type_name)
    sys = IS.SystemData()
    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(sys, component)

    initial_time = Dates.DateTime("2020-09-01")
    resolution = Dates.Hour(1)
    data_series =
        TimeSeries.TimeArray(
            range(initial_time; length = 365, step = resolution),
            test_value,
        )
    data = IS.SingleTimeSeries(; data = data_series, name = "test_c")
    IS.add_time_series!(sys, component, data)
    ts = IS.get_time_series(IS.SingleTimeSeries, component, "test_c";)
    @test split(IS.get_data_type(ts), '.')[end] == type_name
    @test reshape(TimeSeries.values(IS.get_data(ts)), 365) == TimeSeries.values(data_series)
    _test_add_single_time_series_helper(component, initial_time)
end

@testset "Test add SingleTimeSeries with LinearFunctionData Cost" begin
    _test_add_single_time_series_type(
        repeat([IS.LinearFunctionData(3.14, 1.23)], 365),
        "LinearFunctionData",
    )
end

@testset "Test add SingleTimeSeries with QuadraticFunctionData Cost" begin
    _test_add_single_time_series_type(
        repeat([IS.QuadraticFunctionData(999.0, 1.0, 0.5)], 365),
        "QuadraticFunctionData",
    )
end

@testset "Test add SingleTimeSeries with PiecewiseLinearData Cost" begin
    _test_add_single_time_series_type(
        repeat([IS.PiecewiseLinearData(repeat([(999.0, 1.0)], 5))], 365),
        "PiecewiseLinearData",
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
    res = IS.add_time_series_from_file_metadata!(
        data,
        IS.InfrastructureSystemsComponent,
        file,
    )
    @test !isempty(res) && first(res) isa IS.StaticTimeSeriesKey
    @test IS.has_time_series(component)

    all_time_series = get_all_time_series(data)
    @test length(all_time_series) == 1
    time_series = all_time_series[1]
    @test time_series isa IS.SingleTimeSeries

    time_series2 = IS.get_time_series(
        typeof(time_series),
        component,
        IS.get_name(time_series);
        start_time = IS.get_initial_timestamp(time_series),
    )
    @test length(time_series) == length(time_series2)
    @test IS.get_initial_timestamp(time_series) ==
          IS.get_initial_timestamp(time_series2)

    it = IS.get_initial_timestamp(time_series)

    all_time_series = get_all_time_series(data)
    @test length(collect(all_time_series)) == 1

    data = IS.SystemData()
    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(data, component)
    @test !IS.has_time_series(component)
    file = joinpath(FORECASTS_DIR, "ForecastPointers.json")
    IS.add_time_series_from_file_metadata!(
        data,
        IS.InfrastructureSystemsComponent,
        file,
    )
    @test IS.has_time_series(component)

    sys = IS.SystemData()
    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(sys, component)
    @test !IS.has_time_series(component)
    file = joinpath(FORECASTS_DIR, "DateTimeAsColumnDeterministic.csv")
    raw_data = IS.read_time_series(IS.Deterministic, file, "Component1")
    data = IS.Deterministic("test", file, component, Dates.Hour(1))
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
    ts = IS.SingleTimeSeries(;
        name = name,
        data = ta,
        scaling_factor_multiplier = IS.get_val,
    )
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
    ts = IS.SingleTimeSeries(;
        name = name,
        data = ta,
        scaling_factor_multiplier = IS.get_val,
    )
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

    ts_storage = sys.time_series_manager.data_store
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
    time_series1 =
        IS.SingleTimeSeries(;
            name = "val",
            data = ta1,
            scaling_factor_multiplier = IS.get_val,
        )
    time_series2 =
        IS.SingleTimeSeries(;
            name = "val2",
            data = ta2,
            scaling_factor_multiplier = IS.get_val,
        )
    IS.add_time_series!(sys, component, time_series1)
    IS.add_time_series!(sys, component, time_series2)

    @test length(collect(IS.get_time_series_multiple(sys))) == 2
    @test length(collect(IS.get_time_series_multiple(component))) == 2
    @test length(collect(IS.get_time_series_multiple(sys))) == 2

    @test length(
        collect(IS.get_time_series_multiple(sys; type = IS.SingleTimeSeries)),
    ) == 2
    @test length(collect(IS.get_time_series_multiple(sys; type = IS.Probabilistic))) ==
          0

    time_series = collect(IS.get_time_series_multiple(sys))
    @test length(time_series) == 2

    @test length(collect(IS.get_time_series_multiple(sys; name = "val"))) == 1
    @test length(collect(IS.get_time_series_multiple(sys; name = "bad_name"))) == 0

    filter_func = x -> TimeSeries.values(IS.get_data(x))[12] == 12
    @test length(
        collect(IS.get_time_series_multiple(sys, filter_func; name = "val2")),
    ) == 0
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
    IS.remove_time_series!(
        data,
        typeof(time_series),
        component,
        IS.get_name(time_series),
    )

    @test length(get_all_time_series(data)) == 0
    @test IS.get_num_time_series(data) == 0
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
    @test IS.get_num_time_series(data) == 1

    IS.remove_component!(data, component)
    @test length(collect(IS.get_time_series_multiple(component))) == 0
    @test length(collect(IS.get_components(IS.InfrastructureSystemsComponent, data))) ==
          0
    @test length(get_all_time_series(data)) == 0
    @test IS.get_num_time_series(data) == 0
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

    ts = IS.get_time_series(IS.SingleTimeSeries, component, name; start_time = dates[1])
    @test TimeSeries.timestamp(IS.get_data(ts))[1] == dates[1]
    @test length(ts) == 24

    ts = IS.get_time_series(IS.SingleTimeSeries, component, name; start_time = dates[3])
    @test TimeSeries.timestamp(IS.get_data(ts))[1] == dates[3]
    @test length(ts) == 22

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
    @test IS.get_initial_timestamp(time_series) == initial_time
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
    name_mapping = Dict((IS.get_name(component), name1) => name2)
    IS.copy_time_series!(component2, component; name_mapping = name_mapping)
    time_series = IS.get_time_series(IS.SingleTimeSeries, component2, name2)
    @test time_series isa IS.SingleTimeSeries
    @test IS.get_initial_timestamp(time_series) == initial_time
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
    name_mapping = Dict((IS.get_name(component), name2a) => name2b)
    IS.copy_time_series!(component2, component; name_mapping = name_mapping)
    time_series = IS.get_time_series(IS.SingleTimeSeries, component2, name2b)
    @test time_series isa IS.SingleTimeSeries
    @test IS.get_initial_timestamp(time_series) == initial_time2
    @test IS.get_name(time_series) == name2b
    @test_throws ArgumentError IS.get_time_series(
        IS.SingleTimeSeries,
        component2,
        name2a,
    )
end

@testset "Test copy time_series with transformed time series" begin
    sys = create_system_data(; time_series_in_memory = true)
    components = collect(IS.get_components(IS.InfrastructureSystemsComponent, sys))
    @test length(components) == 1
    component = components[1]

    resolution = Dates.Minute(5)
    dates = create_dates("2020-01-01T00:00:00", resolution, "2020-01-01T23:00:00")
    data = collect(1:length(dates))
    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    name = "val"
    ts = IS.SingleTimeSeries(name, ta)
    IS.add_time_series!(sys, component, ts)
    horizon = 6
    interval = Dates.Minute(10)
    IS.transform_single_time_series!(
        sys,
        IS.DeterministicSingleTimeSeries,
        horizon,
        interval,
    )

    component2 = IS.TestComponent("component2", 6)
    IS.add_component!(sys, component2)
    IS.copy_time_series!(component2, component)

    time_series = IS.get_time_series(IS.SingleTimeSeries, component2, name)
    @test time_series isa IS.SingleTimeSeries
    @test IS.get_initial_timestamp(time_series) == dates[1]
    @test IS.get_name(time_series) == name

    time_series = IS.get_time_series(IS.DeterministicSingleTimeSeries, component2, name)
    @test time_series isa IS.DeterministicSingleTimeSeries
    @test IS.get_initial_timestamp(time_series) == dates[1]
    @test IS.get_name(time_series) == name
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

@testset "Test time_series to" begin
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

@testset "Test Scenarios time_series" begin
    for in_memory in (true, false)
        sys = IS.SystemData(; time_series_in_memory = in_memory)
        sys = IS.SystemData()
        name = "Component1"
        name = "val"
        component = IS.TestComponent(name, 5)
        IS.add_component!(sys, component)

        initial_timestamp = Dates.DateTime("2020-01-01T00:00:00")
        horizon = 24
        resolution = Dates.Hour(1)
        scenario_count = 2
        data_input = rand(horizon, scenario_count)
        data = SortedDict(initial_timestamp => data_input)
        time_series = IS.Scenarios(;
            name = name,
            resolution = resolution,
            scenario_count = scenario_count,
            data = data,
        )
        fdata = IS.get_data(time_series)
        @test size(first(values(fdata)))[2] == 2
        @test initial_timestamp == first(keys((fdata)))
        @test data_input == first(values((fdata)))

        IS.add_time_series!(sys, component, time_series)
        time_series2 = IS.get_time_series(IS.Scenarios, component, name)
        @test time_series2 isa IS.Scenarios
        fdata2 = IS.get_data(time_series2)
        @test size(first(values(fdata2)))[2] == 2
        @test initial_timestamp == first(keys((fdata2)))
        @test data_input == first(values((fdata2)))
    end
end

@testset "Test Probabilistic time_series" begin
    for in_memory in (true, false)
        sys = IS.SystemData(; time_series_in_memory = in_memory)
        name = "Component1"
        name = "val"
        component = IS.TestComponent(name, 5)
        IS.add_component!(sys, component)

        initial_timestamp = Dates.DateTime("2020-01-01T00:00:00")
        horizon = 24
        resolution = Dates.Hour(1)
        percentiles = 1:99
        data_input = rand(horizon, length(percentiles))
        data = SortedDict(initial_timestamp => data_input)
        time_series = IS.Probabilistic(;
            name = name,
            resolution = resolution,
            percentiles = percentiles,
            data = data,
        )
        fdata = IS.get_data(time_series)
        @test size(first(values(fdata)))[2] == length(percentiles)
        @test initial_timestamp == first(keys((fdata)))
        @test data_input == first(values((fdata)))

        IS.add_time_series!(sys, component, time_series)
        time_series2 = IS.get_time_series(IS.Probabilistic, component, name)
        @test time_series2 isa IS.Probabilistic
        fdata2 = IS.get_data(time_series2)
        @test size(first(values(fdata2)))[2] == length(percentiles)
        @test initial_timestamp == first(keys((fdata2)))
        @test data_input == first(values((fdata2)))
    end
end

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
    time_series = IS.SingleTimeSeries(; name = "val", data = ta)
    @test_throws ArgumentError IS.add_time_series!(sys, component, time_series)
end

@testset "Test system time series parameters" begin
    sys = IS.SystemData()
    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(sys, component)

    @test isempty(IS.get_forecast_initial_times(sys))

    resolution = Dates.Hour(1)
    initial_time = Dates.DateTime("2020-09-01")
    second_time = initial_time + resolution
    name = "test_forecast"
    horizon = 24
    data = SortedDict(initial_time => ones(horizon), second_time => ones(horizon))

    forecast = IS.Deterministic(; data = data, name = name, resolution = resolution)
    IS.add_time_series!(sys, component, forecast)

    sts_data =
        TimeSeries.TimeArray(
            range(initial_time; length = 365, step = resolution),
            ones(365),
        )
    sts = IS.SingleTimeSeries(; data = sts_data, name = "test_sts")
    IS.add_time_series!(sys, component, sts)

    @test IS.get_forecast_window_count(sys) == 2
    @test IS.get_forecast_horizon(sys) == horizon
    @test IS.get_forecast_initial_timestamp(sys) == initial_time
    @test IS.get_forecast_interval(sys) == second_time - initial_time
    @test IS.get_forecast_initial_times(sys) == [initial_time, second_time]
    @test collect(IS.get_initial_times(forecast)) ==
          collect(IS.get_forecast_initial_times(sys))
end

# TODO something like this could be much more widespread to reduce code duplication
default_time_params = (
    interval = Dates.Hour(1),
    initial_timestamp = Dates.DateTime("2020-09-01"),
    initial_times = collect(
        range(Dates.DateTime("2020-09-01"); length = 24, step = Dates.Hour(1)),
    ),
    horizon = 24,
)

function _test_get_time_series_option_type(test_data, in_memory, extended)
    sys = IS.SystemData(; time_series_in_memory = in_memory)
    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(sys, component)

    # Set baseline parameters for the rest of the tests.
    resolution = Dates.Minute(5)
    name = "test"

    forecast = if extended
        IS.Deterministic(; data = test_data, name = name, resolution = resolution)
    else
        IS.Deterministic(name, test_data, resolution)
    end
    IS.add_time_series!(sys, component, forecast)
    @test IS.get_forecast_window_count(sys) == length(test_data)

    f2 = IS.get_time_series(IS.Deterministic, component, name)
    @test IS.get_count(f2) == length(test_data)
    @test IS.get_initial_timestamp(f2) == default_time_params.initial_times[1]
    for (i, window) in enumerate(IS.iterate_windows(f2))
        @test TimeSeries.values(window) ==
              test_data[default_time_params.initial_times[i]]
    end

    if extended
        offset = 1
        count = 1
        it = default_time_params.initial_times[offset]
        f2 = IS.get_time_series(
            IS.Deterministic,
            component,
            name;
            start_time = it,
            count = count,
        )
        @test IS.get_initial_timestamp(f2) == it
        @test IS.get_count(f2) == count
        @test IS.get_horizon(f2) == default_time_params.horizon
        for (i, window) in enumerate(IS.iterate_windows(f2))
            @test TimeSeries.values(window) ==
                  test_data[default_time_params.initial_times[i + offset - 1]]
        end
    end

    offset = 12
    count = 5
    it = default_time_params.initial_times[offset]
    f2 = IS.get_time_series(
        IS.Deterministic,
        component,
        name;
        start_time = it,
        count = count,
    )
    @test IS.get_initial_timestamp(f2) == it
    @test IS.get_count(f2) == count
    @test IS.get_horizon(f2) == default_time_params.horizon
    for (i, window) in enumerate(IS.iterate_windows(f2))
        @test TimeSeries.values(window) ==
              test_data[default_time_params.initial_times[i + offset - 1]]
    end

    f2 = IS.get_time_series(
        IS.Deterministic,
        component,
        name;
        start_time = it,
        count = count,
        len = default_time_params.horizon - 1,
    )
    @test IS.get_initial_timestamp(f2) == it
    @test IS.get_count(f2) == count
    @test IS.get_horizon(f2) == default_time_params.horizon - 1
    for (i, window) in enumerate(IS.iterate_windows(f2))
        @test TimeSeries.values(window) ==
              test_data[default_time_params.initial_times[i + offset - 1]][1:(default_time_params.horizon - 1)]
    end

    @test_throws ArgumentError IS.get_time_series(
        IS.Deterministic,
        component,
        name;
        start_time = it + Dates.Minute(1),
    )
end
@testset "Test get_time_series options" begin
    for in_memory in (true, false)
        _test_get_time_series_option_type(
            SortedDict(
                it => ones(default_time_params.horizon) * i for
                (i, it) in enumerate(default_time_params.initial_times)
            ),
            in_memory,
            false,
        )
    end
end

@testset "Test get_time_series options for LinearFunctionData Cost" begin
    for in_memory in (true, false)
        _test_get_time_series_option_type(
            SortedDict{Dates.DateTime, Vector{IS.LinearFunctionData}}(
                it => repeat([IS.LinearFunctionData(3.14 * i, 1.23 * i)], 24) for
                (i, it) in enumerate(default_time_params.initial_times)
            ), in_memory, true)
    end
end

@testset "Test get_time_series options for QuadraticFunctionData Cost" begin
    for in_memory in (true, false)
        _test_get_time_series_option_type(
            SortedDict{Dates.DateTime, Vector{IS.QuadraticFunctionData}}(
                it => repeat([IS.QuadraticFunctionData(999.0, 1.0 * i, 1.23)], 24) for
                (i, it) in enumerate(default_time_params.initial_times)
            ), in_memory, true)
    end
end

@testset "Test get_time_series options for PiecewiseLinearData Cost" begin
    for in_memory in (true, false)
        _test_get_time_series_option_type(
            SortedDict{Dates.DateTime, Vector{IS.PiecewiseLinearData}}(
                it => repeat(
                    [IS.PiecewiseLinearData(repeat([(999.0, 1.0 * i)], 5))],
                    24,
                ) for
                (i, it) in enumerate(default_time_params.initial_times)
            ), in_memory, true)
    end
end

@testset "Test get_time_series_array SingleTimeSeries" begin
    sys = IS.SystemData()
    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(sys, component)

    dates = create_dates("2020-01-01T00:00:00", Dates.Hour(1), "2020-01-01T23:00:00")
    data = collect(1:24)
    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    name = "val"
    ts = IS.SingleTimeSeries(name, ta; scaling_factor_multiplier = IS.get_val)
    IS.add_time_series!(sys, component, ts)

    # Get data from storage, defaults.
    ta2 = IS.get_time_series_array(IS.SingleTimeSeries, component, name)
    @test ta2 isa TimeSeries.TimeArray
    @test TimeSeries.timestamp(ta2) == dates
    @test TimeSeries.timestamp(ta2) ==
          IS.get_time_series_timestamps(IS.SingleTimeSeries, component, name)
    @test TimeSeries.values(ta2) == data * IS.get_val(component)
    @test TimeSeries.values(ta2) ==
          IS.get_time_series_values(IS.SingleTimeSeries, component, name)

    # Get data from storage, custom offsets
    ta2 = IS.get_time_series_array(
        IS.SingleTimeSeries,
        component,
        name;
        start_time = dates[5],
        len = 5,
    )
    @test TimeSeries.timestamp(ta2) == dates[5:9]
    @test TimeSeries.timestamp(ta2) == IS.get_time_series_timestamps(
        IS.SingleTimeSeries,
        component,
        name;
        start_time = dates[5],
        len = 5,
    )
    @test TimeSeries.values(ta2) == data[5:9] * IS.get_val(component)
    @test TimeSeries.values(ta2) == IS.get_time_series_values(
        IS.SingleTimeSeries,
        component,
        name;
        start_time = dates[5],
        len = 5,
    )

    # Get data from storage, ignore_scaling_factors.
    ta2 = IS.get_time_series_array(
        IS.SingleTimeSeries,
        component,
        name;
        start_time = dates[5],
        ignore_scaling_factors = true,
    )
    @test TimeSeries.timestamp(ta2) == dates[5:end]
    @test TimeSeries.values(ta2) == data[5:end]

    # Get data from cached instance, defaults
    ta2 = IS.get_time_series_array(component, ts)
    @test TimeSeries.timestamp(ta2) == dates
    @test TimeSeries.timestamp(ta2) == IS.get_time_series_timestamps(component, ts)
    @test TimeSeries.values(ta2) == data * IS.get_val(component)
    @test TimeSeries.values(ta2) == IS.get_time_series_values(component, ts)

    # Get data from cached instance, custom offsets
    ta2 = IS.get_time_series_array(component, ts, dates[5]; len = 5)
    @test TimeSeries.timestamp(ta2) == dates[5:9]
    @test TimeSeries.timestamp(ta2) ==
          IS.get_time_series_timestamps(component, ts, dates[5]; len = 5)
    @test TimeSeries.values(ta2) == data[5:9] * IS.get_val(component)
    @test TimeSeries.values(ta2) ==
          IS.get_time_series_values(component, ts, dates[5]; len = 5)

    # Get data from cached instance, custom offsets, ignore_scaling_factors.
    ta2 = IS.get_time_series_array(
        component,
        ts,
        dates[5];
        len = 5,
        ignore_scaling_factors = true,
    )
    @test TimeSeries.timestamp(ta2) == dates[5:9]
    @test TimeSeries.values(ta2) == data[5:9]
    @test TimeSeries.values(ta2) == IS.get_time_series_values(
        component,
        ts,
        dates[5];
        len = 5,
        ignore_scaling_factors = true,
    )

    IS.clear_time_series!(sys)

    # No scaling_factor_multiplier
    ts = IS.SingleTimeSeries(name, ta)
    IS.add_time_series!(sys, component, ts)
    ta2 = IS.get_time_series_array(IS.SingleTimeSeries, component, name)
    @test ta2 isa TimeSeries.TimeArray
    @test TimeSeries.timestamp(ta2) == dates
    @test TimeSeries.values(ta2) == data
    @test IS.get_time_series_timestamps(IS.SingleTimeSeries, component, name) == dates
    @test IS.get_time_series_values(IS.SingleTimeSeries, component, name) == data
end

@testset "Test get_time_series_array Deterministic" begin
    sys = IS.SystemData()
    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(sys, component)

    resolution = Dates.Minute(5)
    interval = Dates.Hour(1)
    initial_timestamp = Dates.DateTime("2020-09-01")
    initial_times = collect(range(initial_timestamp; length = 2, step = interval))
    name = "test"
    horizon = 24
    data = SortedDict(it => ones(horizon) * i for (i, it) in enumerate(initial_times))

    forecast =
        IS.Deterministic(name, data, resolution; scaling_factor_multiplier = IS.get_val)
    IS.add_time_series!(sys, component, forecast)
    start_time = initial_timestamp + interval
    # Verify all permutations with defaults.
    ta2 =
        IS.get_time_series_array(
            IS.Deterministic,
            component,
            name;
            start_time = start_time,
        )

    @test ta2 isa TimeSeries.TimeArray
    @test TimeSeries.timestamp(ta2) ==
          collect(range(start_time; length = horizon, step = resolution))
    @test TimeSeries.timestamp(ta2) == IS.get_time_series_timestamps(
        IS.Deterministic,
        component,
        name;
        start_time = start_time,
    )
    @test TimeSeries.timestamp(ta2) ==
          IS.get_time_series_timestamps(component, forecast, start_time)
    @test TimeSeries.values(ta2) == data[initial_times[2]] * IS.get_val(component)
    @test TimeSeries.values(ta2) == IS.get_time_series_values(
        IS.Deterministic,
        component,
        name;
        start_time = start_time,
    )
    @test TimeSeries.values(ta2) ==
          IS.get_time_series_values(component, forecast, start_time)
    @test TimeSeries.values(ta2) ==
          TimeSeries.values(IS.get_time_series_array(component, forecast, start_time))

    # ignore_scaling_factors
    TimeSeries.values(
        IS.get_time_series_array(
            IS.Deterministic,
            component,
            name;
            start_time = start_time,
            ignore_scaling_factors = true,
        ),
    ) == data[start_time]
    IS.get_time_series_values(
        IS.Deterministic,
        component,
        name;
        start_time = start_time,
        ignore_scaling_factors = true,
    ) == data[start_time]
    IS.get_time_series_values(
        component,
        forecast,
        start_time;
        ignore_scaling_factors = true,
    ) == data[start_time]

    # Custom length
    len = 10
    @test TimeSeries.timestamp(ta2)[1:10] == IS.get_time_series_timestamps(
        IS.Deterministic,
        component,
        name;
        start_time = start_time,
        len = 10,
    )
    @test TimeSeries.timestamp(ta2)[1:10] ==
          IS.get_time_series_timestamps(component, forecast, start_time; len = 10)
    @test TimeSeries.values(ta2)[1:10] == IS.get_time_series_values(
        IS.Deterministic,
        component,
        name;
        start_time = start_time,
        len = len,
    )
    @test TimeSeries.values(ta2)[1:10] ==
          IS.get_time_series_values(component, forecast, start_time; len = 10)
    @test TimeSeries.values(ta2)[1:10] == TimeSeries.values(
        IS.get_time_series_array(component, forecast, start_time; len = 10),
    )
end

@testset "Test get_time_series_array Probabilistic" begin
    initial_time = Dates.DateTime("2020-09-01")
    resolution = Dates.Hour(1)
    other_time = initial_time + resolution
    name = "test"
    horizon = 24
    data1 = rand(horizon, 99)
    data2 = rand(horizon, 99)
    data_vec = Dict(initial_time => data1, other_time => data2)
    sys = IS.SystemData()
    component_name = "Component1"
    component = IS.TestComponent(component_name, 5)
    IS.add_component!(sys, component)
    forecast = IS.Probabilistic(name, data_vec, ones(99), resolution)
    IS.add_time_series!(sys, component, forecast)
    @test IS.has_time_series(component)
    @test IS.get_initial_timestamp(forecast) == initial_time
    forecast_retrieved =
        IS.get_time_series(
            IS.Probabilistic,
            component,
            "test";
            start_time = initial_time,
        )
    @test IS.get_initial_timestamp(forecast_retrieved) == initial_time
    t = IS.get_time_series_array(
        IS.Probabilistic,
        component,
        "test";
        start_time = initial_time,
    )
    @test size(t) == (24, 99)
    @test TimeSeries.values(t) == data1

    t = IS.get_time_series_array(
        IS.Probabilistic,
        component,
        "test";
        start_time = initial_time,
        len = 12,
    )
    @test size(t) == (12, 99)
    @test TimeSeries.values(t) == data1[1:12, :]
    t_other =
        IS.get_time_series(IS.Probabilistic, component, "test"; start_time = other_time)
    @test collect(keys(IS.get_data(t_other)))[1] == other_time
end

@testset "Test get_time_series_array Scenarios" begin
    initial_time = Dates.DateTime("2020-09-01")
    resolution = Dates.Hour(1)
    other_time = initial_time + resolution
    name = "test"
    horizon = 24
    data1 = rand(horizon, 99)
    data2 = rand(horizon, 99)
    data_vec = Dict(initial_time => data1, other_time => data2)
    sys = IS.SystemData()
    component_name = "Component1"
    component = IS.TestComponent(component_name, 5)
    IS.add_component!(sys, component)
    forecast = IS.Scenarios(name, data_vec, resolution)
    IS.add_time_series!(sys, component, forecast)
    @test IS.has_time_series(component)
    @test IS.get_initial_timestamp(forecast) == initial_time
    forecast_retrieved =
        IS.get_time_series(IS.Scenarios, component, "test"; start_time = initial_time)
    @test IS.get_initial_timestamp(forecast_retrieved) == initial_time
    t = IS.get_time_series_array(
        IS.Scenarios,
        component,
        "test";
        start_time = initial_time,
    )
    @test size(t) == (24, 99)
    @test TimeSeries.values(t) == data1

    t = IS.get_time_series_array(
        IS.Scenarios,
        component,
        "test";
        start_time = initial_time,
        len = 12,
    )
    @test size(t) == (12, 99)
    @test TimeSeries.values(t) == data1[1:12, :]
    t_other =
        IS.get_time_series(IS.Scenarios, component, "test"; start_time = other_time)
    @test collect(keys(IS.get_data(t_other)))[1] == other_time
end

@testset "Test conflicting time series parameters" begin
    sys = IS.SystemData()
    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(sys, component)

    resolution = Dates.Hour(1)
    initial_time = Dates.DateTime("2020-09-01")
    second_time = initial_time + resolution
    name = "test"
    horizon = 24

    # Horizon must be greater than 1.
    bad_data = SortedDict(initial_time => ones(1), second_time => ones(1))
    forecast = IS.Deterministic(; data = bad_data, name = name, resolution = resolution)
    @test_throws ArgumentError IS.add_time_series!(sys, component, forecast)

    # Arrays must have the same length.
    bad_data = SortedDict(initial_time => ones(2), second_time => ones(3))
    forecast = IS.Deterministic(; data = bad_data, name = name, resolution = resolution)
    @test_throws DimensionMismatch IS.add_time_series!(sys, component, forecast)

    # Set baseline parameters for the rest of the tests.
    data = SortedDict(initial_time => ones(horizon), second_time => ones(horizon))
    forecast = IS.Deterministic(; data = data, name = name, resolution = resolution)
    IS.add_time_series!(sys, component, forecast)

    # Conflicting initial time
    initial_time2 = Dates.DateTime("2020-09-02")
    name = "test2"
    data = SortedDict(initial_time2 => ones(horizon), second_time => ones(horizon))

    forecast = IS.Deterministic(; data = data, name = name, resolution = resolution)
    @test_throws IS.ConflictingInputsError IS.add_time_series!(sys, component, forecast)

    # As of PSY 4.0, different resolutions are allowed.
    resolution2 = Dates.Minute(5)
    name = "test2"
    data = SortedDict(initial_time => ones(horizon), second_time => ones(horizon))

    forecast = IS.Deterministic(; data = data, name = name, resolution = resolution)
    IS.add_time_series!(sys, component, forecast)

    # Conflicting horizon
    forecast = IS.Deterministic(; data = data, name = name, resolution = resolution2)
    @test_throws IS.ConflictingInputsError IS.add_time_series!(sys, component, forecast)

    # Conflicting count
    name = "test3"
    third_time = second_time + resolution
    data = SortedDict(
        initial_time => ones(horizon),
        second_time => ones(horizon),
        third_time => ones(horizon),
    )

    forecast = IS.Deterministic(; data = data, name = name, resolution = resolution)
    @test_throws IS.ConflictingInputsError IS.add_time_series!(sys, component, forecast)
end

@testset "Test deepcopy on HDF5" begin
    sys = IS.SystemData(; time_series_in_memory = false)
    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(sys, component)

    initial_timestamp = Dates.DateTime("2020-01-01T00:00:00")
    horizon = 24
    resolution = Dates.Hour(1)
    data_input = rand(horizon)
    data = SortedDict(initial_timestamp => data_input)
    time_series = IS.Deterministic(; name = name, resolution = resolution, data = data)
    fdata = IS.get_data(time_series)
    @test initial_timestamp == first(keys((fdata)))
    @test data_input == first(values((fdata)))

    IS.add_time_series!(sys, component, time_series)
    new_sys = deepcopy(sys)
    orig_file = IS.get_file_path(sys.time_series_manager.data_store)
    new_file = IS.get_file_path(new_sys.time_series_manager.data_store)
    @test orig_file != new_file

    component2 = IS.get_component(IS.TestComponent, sys, name)
    time_series2 = IS.get_time_series(IS.Deterministic, component2, name)
    @test time_series2 isa IS.Deterministic
    fdata2 = IS.get_data(time_series2)
    @test initial_timestamp == first(keys((fdata2)))
    @test data_input == first(values((fdata2)))
end

@testset "Test copy_h5_file" begin
    function compare_attributes(src, dst)
        src_keys = collect(keys(HDF5.attributes(src)))
        dst_keys = collect(keys(HDF5.attributes(dst)))
        @test !isempty(src_keys)
        @test dst_keys == src_keys
        for name in src_keys
            @test HDF5.read(HDF5.attributes(dst)[name]) ==
                  HDF5.read(HDF5.attributes(src)[name])
        end
    end

    for compression_enabled in (true, false)
        compression = IS.CompressionSettings(; enabled = compression_enabled)
        sys = IS.SystemData(; time_series_in_memory = false, compression = compression)
        @test sys.time_series_manager.data_store.compression.enabled ==
              compression_enabled
        name = "Component1"
        name = "val"
        component = IS.TestComponent(name, 5)
        IS.add_component!(sys, component)

        initial_timestamp = Dates.DateTime("2020-01-01T00:00:00")
        horizon = 24
        resolution = Dates.Hour(1)
        data_input = rand(horizon)
        data = SortedDict(initial_timestamp => data_input)
        for i in 1:2
            time_series =
                IS.Deterministic(;
                    name = "name_$i",
                    resolution = resolution,
                    data = data,
                )
            IS.add_time_series!(sys, component, time_series)
        end
        old_file = IS.get_file_path(sys.time_series_manager.data_store)
        new_file, io = mktemp()
        close(io)
        IS.copy_h5_file(old_file, new_file)

        HDF5.h5open(old_file, "r") do fo
            old_uuids = collect(keys(fo[IS.HDF5_TS_ROOT_PATH]))
            @test length(old_uuids) == 2
            HDF5.h5open(new_file, "r") do fn
                compare_attributes(fo[IS.HDF5_TS_ROOT_PATH], fn[IS.HDF5_TS_ROOT_PATH])
                new_uuids = collect(keys(fn[IS.HDF5_TS_ROOT_PATH]))
                @test length(new_uuids) == 2
                @test old_uuids == new_uuids
                for uuid in new_uuids
                    compare_attributes(
                        fo[IS.HDF5_TS_ROOT_PATH][uuid],
                        fn[IS.HDF5_TS_ROOT_PATH][uuid],
                    )
                    old_data = fo[IS.HDF5_TS_ROOT_PATH][uuid]["data"][:, :]
                    new_data = fn[IS.HDF5_TS_ROOT_PATH][uuid]["data"][:, :]
                    @test old_data == new_data
                end
            end
        end
    end
end

@testset "Test assign_new_uuid_internal! for component with time series" begin
    for in_memory in (true, false)
        sys = IS.SystemData(; time_series_in_memory = in_memory)
        name = "Component1"
        component = IS.TestComponent(name, 5)
        IS.add_component!(sys, component)

        initial_time = Dates.DateTime("2020-09-01")
        resolution = Dates.Hour(1)
        name = "test"

        data =
            TimeSeries.TimeArray(
                range(initial_time; length = 24, step = resolution),
                ones(24),
            )
        data = IS.SingleTimeSeries(; data = data, name = name)
        IS.add_time_series!(sys, component, data)
        @test IS.get_time_series(IS.SingleTimeSeries, component, name) isa
              IS.SingleTimeSeries

        old_uuid = IS.get_uuid(component)
        IS.assign_new_uuid_internal!(component)
        new_uuid = IS.get_uuid(component)
        @test old_uuid != new_uuid

        # The time series storage uses component UUIDs, so they must get updated.
        @test IS.get_time_series(IS.SingleTimeSeries, component, name) isa
              IS.SingleTimeSeries
    end
end

@testset "Test SingleTimeSeries shared by two component fields" begin
    for use_scaling_factor in (true, false)
        for in_memory in (true, false)
            sys = IS.SystemData(; time_series_in_memory = in_memory)
            component = IS.TestComponent("Component1", 2; val2 = 3)
            IS.add_component!(sys, component)

            initial_time = Dates.DateTime("2020-01-01T00:00:00")
            end_time = Dates.DateTime("2020-01-01T23:00:00")
            dates = collect(initial_time:Dates.Hour(1):end_time)
            len = length(dates)
            resolution = Dates.Hour(1)
            data = rand(24)
            ta = TimeSeries.TimeArray(dates, data, ["1"])
            name1 = "val"
            name2 = "val2"
            sfm1 = use_scaling_factor ? IS.get_val : nothing
            sfm2 = use_scaling_factor ? IS.get_val2 : nothing
            ts1a = IS.SingleTimeSeries(;
                name = name1,
                data = ta,
                scaling_factor_multiplier = sfm1,
            )
            IS.add_time_series!(sys, component, ts1a)
            ts2a = IS.SingleTimeSeries(ts1a, name2; scaling_factor_multiplier = sfm2)
            IS.add_time_series!(sys, component, ts2a)
            @test IS.get_num_time_series(sys) == 1
            ts1b = IS.get_time_series(IS.SingleTimeSeries, component, name1)
            ts2b = IS.get_time_series(IS.SingleTimeSeries, component, name2)
            @test ts1b.data == ts2b.data
            ta_vals = TimeSeries.values(ta)
            expected1 = use_scaling_factor ? ta_vals * component.val : ta_vals
            expected2 = use_scaling_factor ? ta_vals * component.val2 : ta_vals
            @test IS.get_time_series_values(
                component,
                ts1b,
                initial_time;
            ) == expected1
            @test IS.get_time_series_values(
                component,
                ts2b,
                initial_time;
            ) == expected2
        end
    end
end

function test_forecasts_with_shared_component_fields(forecast_type)
    for use_scaling_factor in (true, false)
        for in_memory in (true, false)
            sys = IS.SystemData(; time_series_in_memory = in_memory)
            component = IS.TestComponent("Component1", 2; val2 = 3)
            IS.add_component!(sys, component)

            initial_time = Dates.DateTime("2020-01-01T00:00:00")
            end_time = Dates.DateTime("2020-01-01T23:00:00")
            dates = collect(initial_time:Dates.Hour(1):end_time)
            len = length(dates)
            resolution = Dates.Hour(1)
            other_time = initial_time + resolution
            name1 = "val"
            name2 = "val2"
            horizon = 24
            sfm1 = use_scaling_factor ? IS.get_val : nothing
            sfm2 = use_scaling_factor ? IS.get_val2 : nothing
            if forecast_type <: IS.Deterministic
                data =
                    SortedDict(
                        initial_time => rand(horizon),
                        other_time => rand(horizon),
                    )
                forecast1a = IS.Deterministic(;
                    data = data,
                    name = name1,
                    resolution = resolution,
                    scaling_factor_multiplier = sfm1,
                )
            elseif forecast_type <: IS.Probabilistic
                data =
                    Dict(
                        initial_time => rand(horizon, 99),
                        other_time => ones(horizon, 99),
                    )
                forecast1a = IS.Probabilistic(
                    name1,
                    data,
                    ones(99),
                    resolution;
                    scaling_factor_multiplier = sfm1,
                )
            elseif forecast_type <: IS.Scenarios
                data =
                    Dict(
                        initial_time => rand(horizon, 99),
                        other_time => ones(horizon, 99),
                    )
                forecast1a =
                    IS.Scenarios(
                        name1,
                        data,
                        resolution;
                        scaling_factor_multiplier = sfm1,
                    )
            else
                error("Unsupported forecast type: $forecast_type")
            end
            IS.add_time_series!(sys, component, forecast1a)
            forecast2a =
                forecast_type(forecast1a, name2; scaling_factor_multiplier = sfm2)
            IS.add_time_series!(sys, component, forecast2a)
            @test IS.get_num_time_series(sys) == 1
            forecast1b = IS.get_time_series(forecast_type, component, name1)
            forecast2b = IS.get_time_series(forecast_type, component, name2)
            @test forecast1b.data == forecast2b.data
            expected1 =
                if use_scaling_factor
                    data[initial_time] * component.val
                else
                    data[initial_time]
                end
            expected2 = if use_scaling_factor
                data[initial_time] * component.val2
            else
                data[initial_time]
            end
            @test IS.get_time_series_values(
                component,
                forecast1b,
                initial_time;
            ) == expected1
            @test IS.get_time_series_values(
                component,
                forecast2b,
                initial_time;
            ) == expected2
            IS.remove_time_series!(sys, forecast_type, component, "val")
            @test IS.get_num_time_series(sys) == 1
            @test IS.get_time_series_values(
                component,
                forecast2b,
                initial_time;
            ) == expected2
            IS.remove_time_series!(sys, forecast_type, component, "val2")
            @test IS.get_num_time_series(sys) == 0
        end
    end
end

@testset "Test Deterministic shared by two component fields" begin
    test_forecasts_with_shared_component_fields(IS.Deterministic)
end

@testset "Test Probabilistic shared by two component fields" begin
    test_forecasts_with_shared_component_fields(IS.Probabilistic)
end

@testset "Test Scenarios shared by two component fields" begin
    test_forecasts_with_shared_component_fields(IS.Scenarios)
end

@testset "Test custom time series directory via env" begin
    @assert !haskey(ENV, IS.TIME_SERIES_DIRECTORY_ENV_VAR)
    path = mkpath("tmp-ts-dir")
    ENV[IS.TIME_SERIES_DIRECTORY_ENV_VAR] = path
    try
        sys = IS.SystemData()
        @test splitpath(sys.time_series_manager.data_store.file_path)[1] == path
    finally
        pop!(ENV, IS.TIME_SERIES_DIRECTORY_ENV_VAR)
    end
end

@testset "Test time series counts" begin
    sys = create_system_data_shared_time_series(; time_series_in_memory = true)
    counts = IS.get_time_series_counts(sys)
    @test counts.static_time_series_count == 1
    @test counts.components_with_time_series == 2
end

@testset "Test custom time series directories" begin
    @test IS._get_time_series_parent_dir(nothing) == tempdir()
    @test IS._get_time_series_parent_dir(pwd()) == pwd()
    @test_throws ErrorException IS._get_time_series_parent_dir(
        "/some/invalid/directory/",
    )

    ENV["SIENNA_TIME_SERIES_DIRECTORY"] = pwd()
    try
        @test IS._get_time_series_parent_dir() == pwd()
        ENV["SIENNA_TIME_SERIES_DIRECTORY"] = "/some/invalid/directory/"
        @test_throws ErrorException IS._get_time_series_parent_dir()
    finally
        pop!(ENV, "SIENNA_TIME_SERIES_DIRECTORY")
    end
end

@testset "Test get_time_series_uuid" begin
    sys = IS.SystemData()
    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(sys, component)

    initial_time = Dates.DateTime("2020-09-01")
    resolution = Dates.Hour(1)

    data = TimeSeries.TimeArray(
        range(initial_time; length = 365, step = resolution),
        rand(365),
    )
    ts_name = "test"
    ts = IS.SingleTimeSeries(; data = data, name = ts_name)
    uuid = IS.get_uuid(ts)
    IS.add_time_series!(sys, component, ts)
    ts2 = IS.get_time_series_uuid(IS.SingleTimeSeries, component, ts_name)
end

@testset "Test serialization of time series keys" begin
    key = IS.StaticTimeSeriesKey(
        IS.SingleTimeSeries,
        "test",
        Dates.now(),
        Dates.Hour(1),
        12,
        Dict("scenario" => "high"),
    )
    key2 = IS.deserialize(IS.StaticTimeSeriesKey, IS.serialize(key))
    @test key2 !== key
    for field in fieldnames(IS.StaticTimeSeriesKey)
        if field == :features
            @test key2.features["scenario"] == key.features["scenario"]
        else
            @test getproperty(key2, field) == getproperty(key, field)
        end
    end
end
