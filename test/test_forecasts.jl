
@testset "Test read_timeseries_metadata" begin
    file = joinpath(FORECASTS_DIR, "ComponentsAsColumnsNoTime.json")
    forecasts = IS.read_timeseries_metadata(file)
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

    file = joinpath(FORECASTS_DIR, "ComponentsAsColumnsNoTime.json")
    IS.add_forecasts!(InfrastructureSystemsType, data, file)

    forecasts = get_all_forecasts(data)
    @test length(forecasts) == 1
    forecast = forecasts[1]
    @test forecast isa IS.Deterministic
    it = IS.get_initial_time(forecast)

    forecasts = get_all_forecasts(data)
    @test length(collect(forecasts)) == 1

    @test IS.get_forecast_initial_times(data) == [it]
    unique_its = Set{Dates.DateTime}()
    IS.get_forecast_initial_times!(unique_its, component) == [it]
    @test collect(unique_its) == [it]
    @test IS.get_forecasts_initial_time(data) == it
    @test IS.get_forecasts_interval(data) == UNINITIALIZED_PERIOD
    @test IS.get_forecasts_horizon(data) == IS.get_horizon(forecast)
    @test IS.get_forecasts_resolution(data) == IS.get_resolution(forecast)
end

@testset "Test forecast initial times" begin
    sys = IS.SystemData()
    dates1 = collect(Dates.DateTime("1/1/2020 00:00:00", "d/m/y H:M:S") : Dates.Hour(1) :
                     Dates.DateTime("1/1/2020 23:00:00", "d/m/y H:M:S"))
    dates2 = collect(Dates.DateTime("1/2/2020 00:00:00", "d/m/y H:M:S") : Dates.Hour(1) :
                     Dates.DateTime("1/2/2020 23:00:00", "d/m/y H:M:S"))
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
        IS.add_forecast!(sys, ta1, component, "val")
        IS.add_forecast!(sys, ta2, component, "val")
    end

    initial_times = IS.get_forecast_initial_times(sys)
    @test length(initial_times) == 4

    first_initial_time = dates1[1]
    last_initial_time = dates2[1] + Dates.Hour(1)
    @test get_forecasts_initial_time(sys) == first_initial_time
    @test get_forecasts_last_initial_time(sys) == last_initial_time

    @test_logs((:error, r"initial times don't match"),
        @test !IS.validate_forecast_consistency(sys)
    )

    IS.clear_forecasts!(sys)
    for component in components
        ta1 = TimeSeries.TimeArray(dates1, data, [IS.get_name(component)])
        ta2 = TimeSeries.TimeArray(dates2, data, [IS.get_name(component)])
        IS.add_forecast!(sys, ta1, component, "val")
        IS.add_forecast!(sys, ta2, component, "val")
    end

    expected = [dates1[1], dates2[1]]
    for component in components
        @test IS.get_forecast_initial_times(IS.Deterministic, component) == expected
    end

    @test IS.validate_forecast_consistency(sys)
    IS.get_forecasts_interval(sys) == dates2[1] - dates1[1]
end

@testset "Test clear_forecasts" begin
    data = create_system_data(; with_forecasts=true)
    IS.clear_forecasts!(data)
    @test length(get_all_forecasts(data)) == 0
end

@testset "Test that remove_component removes forecasts" begin
    data = create_system_data(; with_forecasts=true)

    components = collect(get_components(InfrastructureSystemsType, data))
    @test length(components) == 1
    component = components[1]

    forecasts = collect(iterate_forecasts(data))
    @test length(forecasts) == 1
    forecast = forecasts[1]
    @test IS.get_num_time_series(data.time_series_storage) == 1

    remove_component!(data, component)
    @test length(collect(get_components(InfrastructureSystemsType, data))) == 0
    @test length(get_all_forecasts(data)) == 0
    @test IS.get_num_time_series(data.time_series_storage) == 0
end

@testset "Summarize forecasts" begin
    data = create_system_data(; with_forecasts=true)
    summary(devnull, data.forecast_metadata)
end

#@testset "Test forecast forwarding methods" begin
#    data = create_system_data(; with_forecasts=true)
#    forecast = get_all_forecasts(data)[1]
#
#    # Iteration
#    size = 24
#    @test length(forecast) == size
#    i = 0
#    for x in forecast
#        i += 1
#    end
#    @test i == size
#
#    # Indexing
#    @test length(forecast[1:16]) == 16
#
#    # when
#    fcast = IS.when(forecast, TimeSeries.hour, 3)
#    @test length(fcast) == 1
#end
#
#@testset "Test forecast head" begin
#    data = create_system_data(; with_forecasts=true)
#    forecast = get_all_forecasts(data)[1]
#    fcast = IS.head(forecast)
#    # head returns a length of 6 by default, but don't hard-code that.
#    @test length(fcast) < length(forecast)
#
#    fcast = IS.head(forecast, 10)
#    @test length(fcast) == 10
#end
#
#@testset "Test forecast tail" begin
#    data = create_system_data(; with_forecasts=true)
#    forecast = get_all_forecasts(data)[1]
#    fcast = IS.tail(forecast)
#    # tail returns a length of 6 by default, but don't hard-code that.
#    @test length(fcast) < length(forecast)
#
#    fcast = IS.head(forecast, 10)
#    @test length(fcast) == 10
#end
#
#@testset "Test forecast from" begin
#    data = create_system_data(; with_forecasts=true)
#    forecast = get_all_forecasts(data)[1]
#    start_time = Dates.DateTime(Dates.today()) + Dates.Hour(3)
#    fcast = IS.from(forecast, start_time)
#    @test IS.get_time_series(data, fcast) === IS.get_time_series(data, forecast)
#    @test IS.get_start_index(fcast) == 4
#    @test length(fcast) == 21
#    @test TimeSeries.timestamp(IS.get_timeseries(fcast))[1] == start_time
#end
#
#@testset "Test forecast from" begin
#    data = create_system_data(; with_forecasts=true)
#    forecast = get_all_forecasts(data)[1]
#    for end_time in (Dates.DateTime(Dates.today()) + Dates.Hour(15),
#                     Dates.DateTime(Dates.today()) + Dates.Hour(15) + Dates.Minute(5))
#        fcast = IS.to(forecast, end_time)
#        @test IS.get_time_series(data, fcast) === IS.get_time_series(data, forecast)
#        @test IS.get_start_index(fcast) + IS.get_horizon(fcast) == 17
#        @test length(fcast) == 16
#        @test TimeSeries.timestamp(IS.get_timeseries(fcast))[end] <= end_time
#    end
#end

#@testset "Test forecast serialization" begin
#    data = create_system_data(; with_forecasts=true)
#    forecast = get_all_forecasts(data)[1]
#end
