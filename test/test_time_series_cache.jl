@testset "Test ForecastCache" begin
    sys = IS.SystemData()
    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(sys, component)
    file = joinpath(FORECASTS_DIR, "DateTimeAsColumnDeterministic.csv")
    forecast = IS.Deterministic("test", file, component, Dates.Hour(1))
    initial_timestamp = IS.get_initial_timestamp(forecast)
    initial_times = collect(IS.get_initial_times(forecast))
    interval = IS.get_interval(forecast)
    IS.add_time_series!(sys, component, forecast)

    cache = IS.ForecastCache(IS.Deterministic, component, "test")
    @test cache.in_memory_count == 168
    @test cache.common.next_time == initial_timestamp
    @test cache.common.ts === nothing

    # Iterate over all initial times with default cache size.
    cache = IS.ForecastCache(IS.Deterministic, component, "test")
    for (i, ta) in enumerate(cache)
        it = initial_times[i]
        @test TimeSeries.timestamp(ta) ==
              IS.get_time_series_timestamps(component, forecast, it)
        @test TimeSeries.values(ta) == IS.get_time_series_values(component, forecast, it)
    end

    IS.reset!(cache)
    for it in initial_times
        ta = IS.get_next_time_series_array(cache)
        @test first(TimeSeries.timestamp(ta)) == it
        @test TimeSeries.timestamp(ta) ==
              IS.get_time_series_timestamps(component, forecast, it)
        @test TimeSeries.values(ta) == IS.get_time_series_values(component, forecast, it)
    end
    @test IS.get_next_time(cache) == nothing

    # Iterate over all initial times with custom cache size.
    cache = IS.ForecastCache(IS.Deterministic, component, "test"; cache_size_bytes = 1024)
    for (i, ta) in enumerate(cache)
        it = initial_times[i]
        @test TimeSeries.timestamp(ta) ==
              IS.get_time_series_timestamps(component, forecast, it)
        @test TimeSeries.values(ta) == IS.get_time_series_values(component, forecast, it)
    end

    IS.reset!(cache)
    for it in initial_times
        ta = IS.get_next_time_series_array(cache)
        @test TimeSeries.timestamp(ta) ==
              IS.get_time_series_timestamps(component, forecast, it)
        @test TimeSeries.values(ta) == IS.get_time_series_values(component, forecast, it)
    end

    # Start at an offset.
    cache = IS.ForecastCache(
        IS.Deterministic,
        component,
        "test";
        start_time = Dates.DateTime("2020-01-02T00:00:00"),
    )
    for (i, ta) in enumerate(cache)
        it = initial_times[i + 24]
        @test TimeSeries.timestamp(ta) ==
              IS.get_time_series_timestamps(component, forecast, it)
        @test TimeSeries.values(ta) == IS.get_time_series_values(component, forecast, it)
    end

    # Test caching internals.
    cache = IS.ForecastCache(IS.Deterministic, component, "test"; cache_size_bytes = 1024)
    @test cache.in_memory_count == 5
    @test cache.common.next_time == initial_timestamp
    for it in initial_times[1:(cache.in_memory_count)]
        ta = IS.get_next_time_series_array(cache)
        @test cache.common.last_cached_time == initial_times[5]
        @test TimeSeries.timestamp(ta) ==
              IS.get_time_series_timestamps(component, forecast, it)
        @test TimeSeries.values(ta) == IS.get_time_series_values(component, forecast, it)
    end

    # The next access should trigger a read.
    ta = IS.get_next_time_series_array(cache)
    @test cache.common.last_cached_time == initial_times[10]
    @test TimeSeries.timestamp(ta) ==
          IS.get_time_series_timestamps(component, forecast, initial_times[6])
    @test TimeSeries.values(ta) ==
          IS.get_time_series_values(component, forecast, initial_times[6])
    @test IS.get_next_time(cache) == initial_times[7]
end

@testset "Test StaticTimeSeriesCache" begin
    sys = IS.SystemData()
    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(sys, component)

    initial_timestamp = Dates.DateTime("2020-09-01")
    resolution = Dates.Hour(1)

    data = TimeSeries.TimeArray(
        range(initial_timestamp; length = 365, step = resolution),
        rand(365),
    )
    ts = IS.SingleTimeSeries(data = data, name = "test")
    IS.add_time_series!(sys, component, ts)

    cache = IS.StaticTimeSeriesCache(IS.SingleTimeSeries, component, "test")
    @test cache.in_memory_rows == 365
    @test cache.common.next_time == initial_timestamp
    @test cache.common.ts === nothing

    # Iterate over all initial times with default cache size.
    cache = IS.StaticTimeSeriesCache(IS.SingleTimeSeries, component, "test")
    for (i, ta) in enumerate(cache)
        it = initial_timestamp + (i - 1) * resolution
        @test TimeSeries.timestamp(ta) == IS.get_time_series_timestamps(component, ts, it)
        @test TimeSeries.values(ta) == IS.get_time_series_values(component, ts, it)
    end

    ta = IS.get_next_time_series_array(cache)
    @test first(TimeSeries.timestamp(ta)) == initial_timestamp
    @test TimeSeries.timestamp(ta) ==
          IS.get_time_series_timestamps(component, ts, initial_timestamp)
    @test TimeSeries.values(ta) ==
          IS.get_time_series_values(component, ts, initial_timestamp)

    # Iterate over all initial times with custom cache size.
    cache = IS.StaticTimeSeriesCache(
        IS.SingleTimeSeries,
        component,
        "test";
        cache_size_bytes = 1024,
    )
    @test cache.in_memory_rows == 128
    @test cache.common.num_iterations == 3
    ta = IS.get_next_time_series_array(cache)
    @test first(TimeSeries.timestamp(ta)) == initial_timestamp
    @test length(ta) == 128
    @test TimeSeries.values(ta) == TimeSeries.values(data)[1:128]

    IS.reset!(cache)
    for (i, ta) in enumerate(cache)
        it = initial_timestamp + (i - 1) * cache.in_memory_rows * resolution
        @test TimeSeries.timestamp(ta) ==
              IS.get_time_series_timestamps(component, ts, it; len = length(ta))
        @test TimeSeries.values(ta) ==
              IS.get_time_series_values(component, ts, it; len = length(ta))
    end

    IS.reset!(cache)
    for i in 1:3
        ta = IS.get_next_time_series_array(cache)
        it = initial_timestamp + (i - 1) * cache.in_memory_rows * resolution
        @test TimeSeries.timestamp(ta) ==
              IS.get_time_series_timestamps(component, ts, it; len = length(ta))
        @test TimeSeries.values(ta) ==
              IS.get_time_series_values(component, ts, it; len = length(ta))
    end

    cache = IS.StaticTimeSeriesCache(
        IS.SingleTimeSeries,
        component,
        "test";
        start_time = Dates.DateTime("2020-09-06T08:00:00"),
        cache_size_bytes = 1024,
    )
    @test cache.in_memory_rows == 128
    @test cache.common.num_iterations == 2
    @test cache.common.length_remaining == 365 - 128
    for i in 1:2
        ta = IS.get_next_time_series_array(cache)
        it = initial_timestamp + i * cache.in_memory_rows * resolution
        @test TimeSeries.timestamp(ta) ==
              IS.get_time_series_timestamps(component, ts, it; len = length(ta))
        @test TimeSeries.values(ta) ==
              IS.get_time_series_values(component, ts, it; len = length(ta))
    end
end

@testset "Test DeterministicSingleTimeSeries with ForecastCache" begin
    sys = IS.SystemData()
    component = IS.TestComponent("Component1", 5)
    IS.add_component!(sys, component)

    resolution = Dates.Minute(5)
    dates = create_dates("2020-01-01T00:00:00", resolution, "2020-01-31T23:00:00")
    data = collect(1:length(dates))
    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    name = "val"
    ts = IS.SingleTimeSeries(name, ta)
    IS.add_time_series!(sys, component, ts)
    horizon = 24
    interval = Dates.Hour(1)
    IS.transform_single_time_series!(
        sys,
        IS.DeterministicSingleTimeSeries,
        horizon,
        interval,
    )

    forecast = IS.get_time_series(IS.AbstractDeterministic, component, name)
    initial_times = collect(IS.get_initial_times(forecast))
    cache =
        IS.ForecastCache(IS.AbstractDeterministic, component, name; cache_size_bytes = 1024)

    for (i, ta) in enumerate(cache)
        @test TimeSeries.timestamp(ta) ==
              IS.get_time_series_timestamps(component, forecast, initial_times[i])
        @test TimeSeries.values(ta) ==
              IS.get_time_series_values(component, forecast, initial_times[i])
    end
end

@testset "Test Probabilistic with ForecastCache" begin
    initial_time = Dates.DateTime("2020-09-01")
    interval = Dates.Hour(1)
    resolution = Dates.Hour(1)
    name = "test"
    horizon = 24
    data = SortedDict{Dates.DateTime, Matrix{Float64}}()
    for (i, it) in enumerate(range(initial_time, step = interval, length = 100))
        data[it] = ones(horizon, 99) * i
    end
    sys = IS.SystemData()
    component_name = "Component1"
    component = IS.TestComponent(component_name, 5)
    IS.add_component!(sys, component)
    forecast = IS.Probabilistic(name, data, ones(99), resolution)
    IS.add_time_series!(sys, component, forecast)

    # Iterate over all initial times with custom cache size.
    sz = 1024 * 1024
    cache = IS.ForecastCache(IS.Probabilistic, component, "test"; cache_size_bytes = sz)
    initial_times = collect(keys(data))
    @test cache.in_memory_count == trunc(Int, sz / (99 * 8 * 24))
    for (i, ta) in enumerate(cache)
        it = initial_times[i]
        @test TimeSeries.timestamp(ta) ==
              IS.get_time_series_timestamps(component, forecast, it)
        @test TimeSeries.values(ta) == IS.get_time_series_values(component, forecast, it)
    end
end
