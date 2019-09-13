
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
    component = TestComponent(name, 5)
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
    remove_component!(TestComponent, data, get_name(component))
    @test !does_forecast_have_component(data, component)
end

@testset "Test forecast-component synchronization remove_components" begin
    data = create_system_data(; with_forecasts=true)
    component = collect(iterate_components(data))[1]
    remove_components!(TestComponent, data)
    @test !does_forecast_have_component(data, component)
end

@testset "Summarize forecasts" begin
    data = create_system_data(; with_forecasts=true)
    summary(devnull, data.forecasts)
end
