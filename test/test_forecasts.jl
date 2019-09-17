
import Dates
import TimeSeries

function does_forecast_have_component(data::SystemData, component)
    found = false
    for forecast in iterate_forecasts(data)
        if get_uuid(get_component(forecast)) == get_uuid(component)
            found = true
        end
    end

    return found
end

@testset "Test read_timeseries_metadata" begin
    file = joinpath(FORECASTS_DIR, "ComponentsAsColumnsNoTime.json")
    forecasts = IS.read_timeseries_metadata(file)
    @test length(forecasts) == 1

    for forecast in forecasts
        @test isfile(forecast.data_file)
    end
end

@testset "Test add_forecast from file" begin
    data = SystemData()

    name = "Component1"
    component = IS.TestComponent(name, 5)
    add_component!(data, component)

    file = joinpath(FORECASTS_DIR, "ComponentsAsColumnsNoTime.json")
    add_forecasts!(data, make_forecasts(data, file, IS))

    forecasts = get_all_forecasts(data)
    @test length(forecasts) == 1
    forecast = forecasts[1]
    @test forecast isa Deterministic
    @test get_forecast_component_name(forecast) == name
    it = forecast.initial_time

    forecasts = get_forecasts(Forecast, data, it)
    @test length(collect(forecasts)) == 1

    @test get_forecast_initial_times(data) == [it]
    @test get_forecasts_initial_time(data) == it
    @test get_forecasts_interval(data) == get_resolution(forecast)
    @test get_forecasts_horizon(data) == get_horizon(forecast)
    @test get_forecasts_resolution(data) == get_resolution(forecast)
end 

@testset "Test remove_forecast" begin
    data = create_system_data(; with_forecasts=true)
    forecast = get_all_forecasts(data)[1]
    remove_forecast!(data, forecast)
    @test length(get_all_forecasts(data)) == 0
    @test IS.is_uninitialized(data.forecasts)
end

@testset "Test clear_forecasts" begin
    data = create_system_data(; with_forecasts=true)
    clear_forecasts!(data)
    @test length(get_all_forecasts(data)) == 0
end

@testset "Test forecast-component synchronization remove_component" begin
    data = create_system_data(; with_forecasts=true)
    component = collect(iterate_components(data))[1]
    remove_component!(data, component)
    @test !does_forecast_have_component(data, component)
end

@testset "Test forecast-component synchronization remove_component_by_name" begin
    data = create_system_data(; with_forecasts=true)
    component = collect(iterate_components(data))[1]
    remove_component!(IS.TestComponent, data, get_name(component))
    @test !does_forecast_have_component(data, component)
end

@testset "Test forecast-component synchronization remove_components" begin
    data = create_system_data(; with_forecasts=true)
    component = collect(iterate_components(data))[1]
    remove_components!(IS.TestComponent, data)
    @test !does_forecast_have_component(data, component)
end

@testset "Summarize forecasts" begin
    data = create_system_data(; with_forecasts=true)
    summary(devnull, data.forecasts)
end

@testset "Test split_forecast" begin
    data = create_system_data(; with_forecasts=true)
    forecast = get_all_forecasts(data)[1]

    forecasts = get_forecasts(IS.Deterministic, data, IS.get_initial_time(forecast))
    split_forecasts!(data, forecasts, Dates.Hour(6), 12)
    initial_times = get_forecast_initial_times(data)
    @test length(initial_times) == 3

    for initial_time in initial_times
        for fcast in get_forecasts(Deterministic, data, initial_time)
            # The backing TimeArray must be the same.
            @test get_data(fcast) === get_data(forecast)
            @test length(fcast) == 12
        end
    end
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
    @test get_data(fcast) === get_data(forecast)
    @test get_start_index(fcast) == 4
    @test length(fcast) == 21
    @test TimeSeries.timestamp(IS.get_timeseries(fcast))[1] == start_time
end

@testset "Test forecast from" begin
    data = create_system_data(; with_forecasts=true)
    forecast = get_all_forecasts(data)[1]
    for end_time in (Dates.DateTime(Dates.today()) + Dates.Hour(15),
                     Dates.DateTime(Dates.today()) + Dates.Hour(15) + Dates.Minute(5))
        fcast = IS.to(forecast, end_time)
        @test get_data(fcast) === get_data(forecast)
        @test get_start_index(fcast) + get_horizon(fcast) == 17
        @test length(fcast) == 16
        @test TimeSeries.timestamp(IS.get_timeseries(fcast))[end] <= end_time
    end
end

@testset "Test forecast serialization" begin
    data = create_system_data(; with_forecasts=true)
    forecast = get_all_forecasts(data)[1]
end
