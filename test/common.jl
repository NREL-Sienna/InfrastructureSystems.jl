
function create_system_data(; with_forecasts = false, time_series_in_memory = false)
    data = IS.SystemData(; time_series_in_memory = time_series_in_memory)

    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(data, component)

    if with_forecasts
        file = joinpath(FORECASTS_DIR, "ComponentsAsColumnsNoTime.json")
        IS.add_forecasts!(IS.InfrastructureSystemsComponent, data, file)

        forecasts = get_all_forecasts(data)
        @assert length(forecasts) > 0
    end

    return data
end

function create_system_data_shared_forecasts(; time_series_in_memory = false)
    data = IS.SystemData(; time_series_in_memory = time_series_in_memory)

    name1 = "Component1"
    name2 = "Component2"
    component1 = IS.TestComponent(name1, 5)
    component2 = IS.TestComponent(name2, 6)
    IS.add_component!(data, component1)
    IS.add_component!(data, component2)

    ts_data = create_time_series_data()
    forecast = IS.DeterministicInternal("get_val", ts_data)
    IS.add_forecast!(data, component1, forecast, ts_data)
    IS.add_forecast!(data, component2, forecast, ts_data)

    return data
end

function get_all_forecasts(data)
    return collect(IS.iterate_forecasts(data))
end

function create_time_series_data()
    dates = collect(
        Dates.DateTime("1/1/2020 00:00:00", "d/m/y H:M:S"):Dates.Hour(1):Dates.DateTime(
            "1/1/2020 23:00:00",
            "d/m/y H:M:S",
        ),
    )
    data = collect(1:24)
    component_name = "gen"
    ta = TimeSeries.TimeArray(dates, data, [component_name])
    return IS.TimeSeriesData(ta)
end
