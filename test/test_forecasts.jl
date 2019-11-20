
@testset "Test read_time_series_metadata" begin
    file = joinpath(FORECASTS_DIR, "ComponentsAsColumnsNoTime.json")
    forecasts = IS.read_time_series_metadata(file)
    @test length(forecasts) == 1

    for forecast in forecasts
        @test isfile(forecast.data_file)
    end
end

@testset "Test add_forecast from file" begin
    data = IS.SystemData()

    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(data, component)
    @test !IS.has_forecasts(component)

    file = joinpath(FORECASTS_DIR, "ComponentsAsColumnsNoTime.json")
    IS.add_forecasts!(IS.InfrastructureSystemsType, data, file)
    @test IS.has_forecasts(component)

    forecasts = get_all_forecasts(data)
    @test length(forecasts) == 1
    forecast = forecasts[1]
    @test forecast isa IS.Deterministic

    forecast2 = IS.get_forecast(
        typeof(forecast), component, IS.get_initial_time(forecast), IS.get_label(forecast),
    )
    @test IS.get_horizon(forecast) == IS.get_horizon(forecast2)
    @test IS.get_initial_time(forecast) == IS.get_initial_time(forecast2)

    it = IS.get_initial_time(forecast)

    forecasts = get_all_forecasts(data)
    @test length(collect(forecasts)) == 1

    @test IS.get_forecast_initial_times(data) == [it]
    unique_its = Set{Dates.DateTime}()
    IS.get_forecast_initial_times!(unique_its, component) == [it]
    @test collect(unique_its) == [it]
    @test IS.get_forecasts_initial_time(data) == it
    @test IS.get_forecasts_interval(data) == IS.UNINITIALIZED_PERIOD
    @test IS.get_forecasts_horizon(data) == IS.get_horizon(forecast)
    @test IS.get_forecasts_resolution(data) == IS.get_resolution(forecast)
end

@testset "Test add_forecast" begin
    sys = IS.SystemData()
    name = "Component1"
    component_val = 5
    component = IS.TestComponent(name, component_val)
    IS.add_component!(sys, component)

    dates = collect(Dates.DateTime("2020-01-01T00:00:00") : Dates.Hour(1) :
                    Dates.DateTime("2020-01-01T23:00:00"))
    data = collect(1:24)
    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    forecast = IS.Deterministic("get_val", ta)
    IS.add_forecast!(sys, component, forecast)
    forecast = IS.get_forecast(IS.Deterministic, component, dates[1], "get_val")
    @test forecast isa IS.Deterministic

    name = "Component2"
    component2 = IS.TestComponent(name, component_val)
    @test_throws ArgumentError IS.add_forecast!(sys, component2, forecast)

    # The component name will exist but not the component.
    component3 = IS.TestComponent(name, component_val)
    @test_throws ArgumentError IS.add_forecast!(sys, component3, forecast)
end

# TODO: this is disabled because PowerSystems currently does not set labels correctly.
#@testset "Test add_forecast bad label" begin
#    sys = IS.SystemData()
#    name = "Component1"
#    component_val = 5
#    component = IS.TestComponent(name, component_val)
#    IS.add_component!(sys, component)
#
#    dates = collect(Dates.DateTime("2020-01-01T00:00:00") : Dates.Hour(1) :
#                    Dates.DateTime("2020-01-01T23:00:00"))
#    data = collect(1:24)
#    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
#    forecast = IS.Deterministic("bad-label", ta)
#    @test_throws ArgumentError IS.add_forecast!(sys, component, forecast)
#end

@testset "Test add_forecast from TimeArray" begin
    sys = IS.SystemData()
    name = "Component1"
    component_val = 5
    component = IS.TestComponent(name, component_val)
    IS.add_component!(sys, component)

    dates = collect(Dates.DateTime("2020-01-01T00:00:00") : Dates.Hour(1) :
                    Dates.DateTime("2020-01-01T23:00:00"))
    data = collect(1:24)
    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    IS.add_forecast!(sys, ta, component, "get_val")
    forecast = IS.get_forecast(IS.Deterministic, component, dates[1], "get_val")
    @test forecast isa IS.Deterministic
end

@testset "Test forecast initial times" begin
    sys = IS.SystemData()

    @test_throws ArgumentError IS.get_forecasts_initial_time(sys)
    @test_throws ArgumentError IS.get_forecasts_last_initial_time(sys)

    dates1 = collect(Dates.DateTime("2020-01-01T00:00:00") : Dates.Hour(1) :
                     Dates.DateTime("2020-01-01T23:00:00"))
    dates2 = collect(Dates.DateTime("2020-01-02T00:00:00") : Dates.Hour(1) :
                     Dates.DateTime("2020-01-02T23:00:00"))
    data = collect(1:24)
    components = []

    for i in 1:2
        name = "Component" * string(i)
        component = IS.TestComponent(name, i)
        IS.add_component!(sys, component)
        push!(components, component)
        if i == 1
            dates1_ = dates1
            dates2_ = dates2
        else
            dates1_ = dates1 .+ Dates.Hour(1)
            dates2_ = dates2 .+ Dates.Hour(1)
        end
        ta1 = TimeSeries.TimeArray(dates1_, data, [IS.get_name(component)])
        ta2 = TimeSeries.TimeArray(dates2_, data, [IS.get_name(component)])
        IS.add_forecast!(sys, ta1, component, "get_val")
        IS.add_forecast!(sys, ta2, component, "get_val")
    end

    initial_times = IS.get_forecast_initial_times(sys)
    @test length(initial_times) == 4

    first_initial_time = dates1[1]
    last_initial_time = dates2[1] + Dates.Hour(1)
    @test IS.get_forecasts_initial_time(sys) == first_initial_time
    @test IS.get_forecasts_last_initial_time(sys) == last_initial_time

    @test_logs((:error, r"initial times don't match"),
        @test !IS.validate_forecast_consistency(sys)
    )
    @test_logs((:error, r"initial times don't match"),
        @test_throws IS.DataFormatError !IS.check_forecast_consistency(sys)
    )

    @test IS.get_forecast_counts(sys) == (2, 4)

    IS.clear_forecasts!(sys)
    for component in components
        ta1 = TimeSeries.TimeArray(dates1, data, [IS.get_name(component)])
        ta2 = TimeSeries.TimeArray(dates2, data, [IS.get_name(component)])
        IS.add_forecast!(sys, ta1, component, "get_val")
        IS.add_forecast!(sys, ta2, component, "get_val")
    end

    expected = [dates1[1], dates2[1]]
    for component in components
        @test IS.get_forecast_initial_times(IS.Deterministic, component) == expected
    end

    @test IS.validate_forecast_consistency(sys)
    IS.get_forecasts_interval(sys) == dates2[1] - dates1[1]
end

@testset "Test remove_forecasts" begin
    data = create_system_data(; with_forecasts=true)
    components = collect(IS.iterate_components(data))
    @test length(components) == 1
    component = components[1]
    forecasts = get_all_forecasts(data)
    @test length(get_all_forecasts(data)) == 1

    forecast = forecasts[1]
    IS.remove_forecast!(
        typeof(forecast),
        data,
        component,
        IS.get_initial_time(forecast),
        IS.get_label(forecast),
    )

    @test length(get_all_forecasts(data)) == 0
    @test IS.get_num_time_series(data.time_series_storage) == 0
end

@testset "Test clear_forecasts" begin
    data = create_system_data(; with_forecasts=true)
    IS.clear_forecasts!(data)
    @test length(get_all_forecasts(data)) == 0
end

@testset "Test that remove_component removes forecasts" begin
    data = create_system_data(; with_forecasts=true)

    components = collect(IS.get_components(IS.InfrastructureSystemsType, data))
    @test length(components) == 1
    component = components[1]

    forecasts = collect(IS.iterate_forecasts(data))
    @test length(forecasts) == 1
    forecast = forecasts[1]
    @test IS.get_num_time_series(data.time_series_storage) == 1

    IS.remove_component!(data, component)
    @test length(collect(IS.iterate_forecasts(component))) == 0
    @test length(collect(IS.get_components(IS.InfrastructureSystemsType, data))) == 0
    @test length(get_all_forecasts(data)) == 0
    @test IS.get_num_time_series(data.time_series_storage) == 0
end

@testset "Test get_forecast_values" begin
    sys = IS.SystemData()
    name = "Component1"
    component_val = 5
    component = IS.TestComponent(name, component_val)
    IS.add_component!(sys, component)

    dates = collect(Dates.DateTime("2020-01-01T00:00:00") : Dates.Hour(1) :
                    Dates.DateTime("2020-01-01T23:00:00"))
    data = collect(1:24)
    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    IS.add_forecast!(sys, ta, component, "get_val")
    forecast = IS.get_forecast(IS.Deterministic, component, dates[1], "get_val")

    # Test both versions of the function.
    vals = IS.get_forecast_values(IS, component, forecast)
    @test TimeSeries.timestamp(vals) == dates
    @test TimeSeries.values(vals) == data .* component_val

    vals2 = IS.get_forecast_values(IS.Deterministic, IS, component, dates[1], "get_val")
    @test TimeSeries.timestamp(vals2) == dates
    @test TimeSeries.values(vals2) == data .* component_val
end

@testset "Test get subset of forecast" begin
    sys = create_system_data()
    components = collect(IS.get_components(IS.InfrastructureSystemsType, sys))
    @test length(components) == 1
    component = components[1]

    dates = collect(Dates.DateTime("2020-01-01T00:00:00") : Dates.Hour(1) :
                    Dates.DateTime("2020-01-01T23:00:00"))
    data = collect(1:24)

    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    IS.add_forecast!(sys, ta, component, "get_val")

    forecast = IS.get_forecast(IS.Deterministic, component, dates[1], "get_val")
    @test TimeSeries.timestamp(IS.get_data(forecast))[1] == dates[1]

    forecast = IS.get_forecast(IS.Deterministic, component, dates[3], "get_val", 3)
    @test TimeSeries.timestamp(IS.get_data(forecast))[1] == dates[3]
    @test length(forecast) == 3
end

function validate_generated_initial_times(
                                          forecast_type::Type{<:IS.Forecast},
                                          component::IS.InfrastructureSystemsType,
                                          label::AbstractString,
                                          horizon::Int,
                                          initial_times::Vector{Dates.DateTime},
                                          initial_time::Dates.DateTime,
                                          interval::Dates.Period,
                                          exp_length::Int
                                         )
    @test length(initial_times) == exp_length
    for it in initial_times
        @test it == initial_time
        # Verify all possible forecast ranges.
        for i in 2:horizon
            forecast = IS.get_forecast(forecast_type, component, it, label, i)
            @test IS.get_horizon(forecast) == i
            @test IS.get_initial_time(forecast) == it
            # This will throw if the resolution isn't consistent throughout.
            IS.get_resolution(IS.get_data(forecast))
        end
        initial_time += interval
    end
end

@testset "Test subset from contiguous forecasts" begin
    sys = create_system_data()

    components = collect(IS.get_components(IS.InfrastructureSystemsType, sys))
    @test length(components) == 1
    component = components[1]

    dates1 = collect(Dates.DateTime("2020-01-01T00:00:00") : Dates.Hour(1) :
                     Dates.DateTime("2020-01-01T23:00:00"))
    dates2 = collect(Dates.DateTime("2020-01-02T00:00:00") : Dates.Hour(1) :
                     Dates.DateTime("2020-01-02T23:00:00"))
    dates3 = collect(Dates.DateTime("2020-01-03T00:00:00") : Dates.Hour(1) :
                     Dates.DateTime("2020-01-03T23:00:00"))
    data = collect(1:24)

    label = "get_val"
    ta1 = TimeSeries.TimeArray(dates1, data, [IS.get_name(component)])
    ta2 = TimeSeries.TimeArray(dates2, data, [IS.get_name(component)])
    ta3 = TimeSeries.TimeArray(dates3, data, [IS.get_name(component)])
    IS.add_forecast!(sys, ta1, component, label)
    IS.add_forecast!(sys, ta2, component, label)
    IS.add_forecast!(sys, ta3, component, label)
    initial_times = IS.get_forecast_initial_times(component)
    @test length(initial_times) == 3
    @test IS.are_forecasts_contiguous(component)
    @test IS.are_forecasts_contiguous(sys)

    interval = Dates.Hour(1)
    horizon = 55
    initial_times = IS.generate_initial_times(component, interval, horizon)
    validate_generated_initial_times(
        IS.Deterministic, component, label, horizon, initial_times, dates1[1], interval, 18
    )

    invalid_it = Dates.DateTime("2020-01-20T00:00:00")
    @test_throws ArgumentError IS.get_forecast(IS.Deterministic, component, invalid_it, label, horizon)
end

@testset "Test generate_initial_times" begin
    sys = create_system_data()
    components = collect(IS.get_components(IS.InfrastructureSystemsType, sys))
    @test length(components) == 1
    component = components[1]

    dates = collect(Dates.DateTime("2020-01-01T00:00:00") : Dates.Hour(1) :
                    Dates.DateTime("2020-01-01T23:00:00"))
    data = collect(1:24)

    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    label = "get_val"
    IS.add_forecast!(sys, ta, component, label)
    initial_times = IS.get_forecast_initial_times(component)
    @test length(initial_times) == 1

    horizon = 24
    interval = Dates.Hour(1)
    initial_times = IS.generate_initial_times(component, interval, horizon)
    validate_generated_initial_times(
        IS.Deterministic, component, label, horizon, initial_times, dates[1], interval, 1
    )

    horizon = 12
    interval = Dates.Hour(1)
    initial_times = IS.generate_initial_times(component, interval, horizon)
    validate_generated_initial_times(
        IS.Deterministic, component, label, horizon, initial_times, dates[1], interval, 13
    )

    horizon = 6
    interval = Dates.Hour(3)
    initial_times = IS.generate_initial_times(component, interval, horizon)
    validate_generated_initial_times(
        IS.Deterministic, component, label, horizon, initial_times, dates[1], interval, 7
    )

    horizon = 6
    interval = Dates.Hour(4)
    initial_times = IS.generate_initial_times(component, interval, horizon)
    validate_generated_initial_times(
        IS.Deterministic, component, label, horizon, initial_times, dates[1], interval, 5
    )

    # Test through the system.
    horizon = 6
    initial_times = IS.generate_initial_times(sys, interval, horizon)
    validate_generated_initial_times(
        IS.Deterministic, component, label, horizon, initial_times, dates[1], interval, 5
    )
    IS.clear_forecasts!(sys)
    @test_throws ArgumentError IS.generate_initial_times(sys, interval, 6)
end

@testset "Test generate_initial_times contiguous" begin
    sys = create_system_data()

    components = collect(IS.get_components(IS.InfrastructureSystemsType, sys))
    @test length(components) == 1
    component = components[1]

    @test_throws ArgumentError IS.are_forecasts_contiguous(component)
    @test_throws ArgumentError IS.are_forecasts_contiguous(sys)

    dates1 = collect(Dates.DateTime("2020-01-01T00:00:00") : Dates.Hour(1) :
                     Dates.DateTime("2020-01-01T23:00:00"))
    dates2 = collect(Dates.DateTime("2020-01-02T00:00:00") : Dates.Hour(1) :
                     Dates.DateTime("2020-01-02T23:00:00"))
    data = collect(1:24)

    label = "get_val"
    ta1 = TimeSeries.TimeArray(dates1, data, [IS.get_name(component)])
    ta2 = TimeSeries.TimeArray(dates2, data, [IS.get_name(component)])
    IS.add_forecast!(sys, ta1, component, label)
    IS.add_forecast!(sys, ta2, component, label)
    initial_times = IS.get_forecast_initial_times(component)
    @test length(initial_times) == 2
    @test IS.are_forecasts_contiguous(component)
    @test IS.are_forecasts_contiguous(sys)

    interval = Dates.Hour(1)
    horizon = 48
    initial_times = IS.generate_initial_times(component, interval, horizon)
    validate_generated_initial_times(
        IS.Deterministic, component, label, horizon, initial_times, dates1[1], interval, 1)

    horizon = 24
    interval = Dates.Hour(1)
    initial_times = IS.generate_initial_times(component, interval, horizon)
    validate_generated_initial_times(
        IS.Deterministic, component, label, horizon, initial_times, dates1[1], interval, 25)

    horizon = 12
    interval = Dates.Hour(1)
    initial_times = IS.generate_initial_times(component, interval, horizon)
    validate_generated_initial_times(
        IS.Deterministic, component, label, horizon, initial_times, dates1[1], interval, 37)

    horizon = 6
    interval = Dates.Hour(3)
    initial_times = IS.generate_initial_times(component, interval, horizon)
    validate_generated_initial_times(
        IS.Deterministic, component, label, horizon, initial_times, dates1[1], interval, 15)

    horizon = 6
    interval = Dates.Hour(4)
    initial_times = IS.generate_initial_times(component, interval, horizon)
    validate_generated_initial_times(
        IS.Deterministic, component, label, horizon, initial_times, dates1[1], interval, 11)

    # Run once on the system.
    horizon = 6
    initial_times = IS.generate_initial_times(sys, interval, horizon)
    validate_generated_initial_times(
        IS.Deterministic, component, label, horizon, initial_times, dates1[1], interval, 11)
end

@testset "Test generate_initial_times overlapping" begin
    sys = create_system_data()

    @test_throws ArgumentError IS.generate_initial_times(sys, Dates.Hour(3), 6)

    components = collect(IS.get_components(IS.InfrastructureSystemsType, sys))
    @test length(components) == 1
    component = components[1]

    dates1 = collect(Dates.DateTime("2020-01-01T00:00:00") : Dates.Hour(1) :
                     Dates.DateTime("2020-01-01T23:00:00"))
    dates2 = collect(Dates.DateTime("2020-01-01T01:00:00") : Dates.Hour(1) :
                     Dates.DateTime("2020-01-02T00:00:00"))
    data = collect(1:24)

    ta1 = TimeSeries.TimeArray(dates1, data, [IS.get_name(component)])
    ta2 = TimeSeries.TimeArray(dates2, data, [IS.get_name(component)])
    IS.add_forecast!(sys, ta1, component, "get_val")
    @test_throws ArgumentError IS.generate_initial_times(sys, Dates.Minute(30), 6)

    IS.add_forecast!(sys, ta2, component, "get_val")
    @test_throws ArgumentError IS.generate_initial_times(sys, Dates.Hour(3), 6)

    @test !IS.are_forecasts_contiguous(component)
    @test !IS.are_forecasts_contiguous(sys)
end

@testset "Test generate_initial_times non-contiguous" begin
    sys = create_system_data()

    @test_throws ArgumentError IS.generate_initial_times(sys, Dates.Hour(3), 6)

    components = collect(IS.get_components(IS.InfrastructureSystemsType, sys))
    @test length(components) == 1
    component = components[1]

    dates1 = collect(Dates.DateTime("2020-01-01T00:00:00") : Dates.Hour(1) :
                     Dates.DateTime("2020-01-01T23:00:00"))
    # Skip 1 hour.
    dates2 = collect(Dates.DateTime("2020-01-02T01:00:00") : Dates.Hour(1) :
                     Dates.DateTime("2020-01-03T00:00:00"))
    data = collect(1:24)

    ta1 = TimeSeries.TimeArray(dates1, data, [IS.get_name(component)])
    ta2 = TimeSeries.TimeArray(dates2, data, [IS.get_name(component)])
    IS.add_forecast!(sys, ta1, component, "get_val")
    @test_throws ArgumentError IS.generate_initial_times(sys, Dates.Minute(30), 6)

    IS.add_forecast!(sys, ta2, component, "get_val")
    @test_throws ArgumentError IS.generate_initial_times(sys, Dates.Hour(3), 6)

    @test !IS.are_forecasts_contiguous(component)
    @test !IS.are_forecasts_contiguous(sys)
end

@testset "Test generate_initial_times offset from first initial_time" begin
    sys = create_system_data()

    components = collect(IS.get_components(IS.InfrastructureSystemsType, sys))
    @test length(components) == 1
    component = components[1]

    dates = collect(Dates.DateTime("2020-01-01T00:00:00") : Dates.Hour(1) :
                    Dates.DateTime("2020-01-01T23:00:00"))
    data = collect(1:24)

    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    IS.add_forecast!(sys, ta, component, "get_val")
    resolution = IS.get_forecasts_resolution(sys)
    initial_times = IS.get_forecast_initial_times(component)
    @test length(initial_times) == 1

    horizon = 6
    offset = 1
    interval = resolution * 2
    initial_time = initial_times[1] + offset * resolution

    expected = collect(Dates.DateTime("2020-01-01T01:00:00") : interval :
                       Dates.DateTime("2020-01-01T17:00:00"))

    actual = IS.generate_initial_times(component, interval, horizon;
                                       initial_time=initial_time)
    @test actual == expected

    # Repeat on the system.
    actual = IS.generate_initial_times(sys, interval, horizon; initial_time=initial_time)
    @test actual == expected
end

@testset "Test component-forecast being added to multiple systems" begin
    sys1 = IS.SystemData()
    sys2 = IS.SystemData()
    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(sys1, component)

    dates = collect(Dates.DateTime("2020-01-01T00:00:00") : Dates.Hour(1) :
                    Dates.DateTime("2020-01-01T23:00:00"))
    data = collect(1:24)
    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    IS.add_forecast!(sys1, ta, component, "get_val")

    @test_throws ArgumentError IS.add_component!(sys1, component)
end

@testset "Summarize forecasts" begin
    data = create_system_data(; with_forecasts=true)
    summary(devnull, data.forecast_metadata)
end

@testset "Test forecast forwarding methods" begin
    data = create_system_data(; with_forecasts=true)
    forecast = get_all_forecasts(data)[1]

    # Iteration
    size = 24
    @test length(forecast) == size
    i = 0
    for x in forecast
        i += 1
    end
    @test i == size

    # Indexing
    @test length(forecast[1:16]) == 16

    # when
    fcast = IS.when(forecast, TimeSeries.hour, 3)
    @test length(fcast) == 1
end

@testset "Test forecast head" begin
    data = create_system_data(; with_forecasts=true)
    forecast = get_all_forecasts(data)[1]
    fcast = IS.head(forecast)
    # head returns a length of 6 by default, but don't hard-code that.
    @test length(fcast) < length(forecast)

    fcast = IS.head(forecast, 10)
    @test length(fcast) == 10
end

@testset "Test forecast tail" begin
    data = create_system_data(; with_forecasts=true)
    forecast = get_all_forecasts(data)[1]
    fcast = IS.tail(forecast)
    # tail returns a length of 6 by default, but don't hard-code that.
    @test length(fcast) < length(forecast)

    fcast = IS.head(forecast, 10)
    @test length(fcast) == 10
end

@testset "Test forecast from" begin
    data = create_system_data(; with_forecasts=true)
    forecast = get_all_forecasts(data)[1]
    start_time = Dates.DateTime(Dates.today()) + Dates.Hour(3)
    fcast = IS.from(forecast, start_time)
    @test length(fcast) == 21
    @test TimeSeries.timestamp(IS.get_data(fcast))[1] == start_time
end

@testset "Test forecast from" begin
    data = create_system_data(; with_forecasts=true)
    forecast = get_all_forecasts(data)[1]
    for end_time in (Dates.DateTime(Dates.today()) + Dates.Hour(15),
                     Dates.DateTime(Dates.today()) + Dates.Hour(15) + Dates.Minute(5))
        fcast = IS.to(forecast, end_time)
        @test length(fcast) == 16
        @test TimeSeries.timestamp(IS.get_data(fcast))[end] <= end_time
    end
end

@testset "Test ScenarioBased forecasts" begin
    sys = IS.SystemData()
    name = "Component1"
    label = "get_val"
    component = IS.TestComponent(name, 5)
    IS.add_component!(sys, component)

    dates = collect(Dates.DateTime("2020-01-01T00:00:00") : Dates.Hour(1) :
                    Dates.DateTime("2020-01-01T23:00:00"))
    data = ones(24, 2)
    ta = TimeSeries.TimeArray(dates, data)
    forecast = IS.ScenarioBased(label, ta)
    fdata = IS.get_data(forecast)
    @test length(TimeSeries.colnames(fdata)) == 2
    @test TimeSeries.timestamp(ta) == TimeSeries.timestamp(fdata)
    @test TimeSeries.values(ta) == TimeSeries.values(fdata)

    IS.add_forecast!(sys, component, forecast)
    forecast2 = IS.get_forecast(IS.ScenarioBased, component, dates[1], label)
    @test forecast2 isa IS.ScenarioBased
    fdata2 = IS.get_data(forecast2)
    @test length(TimeSeries.colnames(fdata2)) == 2
    @test TimeSeries.timestamp(ta) == TimeSeries.timestamp(fdata2)
    @test TimeSeries.values(ta) == TimeSeries.values(fdata2)
end

@testset "Add forecast to unsupported struct" begin
    struct TestComponentNoForecasts <: IS.InfrastructureSystemsType
        name::AbstractString
        internal::IS.InfrastructureSystemsInternal
    end

    function TestComponentNoForecasts(name)
        return TestComponentNoForecasts(name, IS.InfrastructureSystemsInternal())
    end

    sys = IS.SystemData()
    name = "component"
    component = TestComponentNoForecasts(name)
    IS.add_component!(sys, component)
    dates = collect(Dates.DateTime("2020-01-01T00:00:00") : Dates.Hour(1) :
                    Dates.DateTime("2020-01-01T23:00:00"))
    data = collect(1:24)
    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    forecast = IS.Deterministic("get_val", ta)
    @test_throws ArgumentError IS.add_forecast!(sys, component, forecast)
end
