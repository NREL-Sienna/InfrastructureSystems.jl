
function create_system_data(; with_time_series = false, time_series_in_memory = false)
    data = IS.SystemData(; time_series_in_memory = time_series_in_memory)

    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(data, component)

    if with_time_series
        file = joinpath(FORECASTS_DIR, "ComponentsAsColumnsNoTime.json")
        IS.add_time_series!(IS.InfrastructureSystemsComponent, data, file)

        time_series = get_all_time_series(data)
        @assert length(time_series) > 0
    end

    return data
end

function create_system_data_shared_time_series(; time_series_in_memory = false)
    data = IS.SystemData(; time_series_in_memory = time_series_in_memory)

    name1 = "Component1"
    name2 = "Component2"
    component1 = IS.TestComponent(name1, 5)
    component2 = IS.TestComponent(name2, 6)
    IS.add_component!(data, component1)
    IS.add_component!(data, component2)

    ta = create_time_array()
    ts_metadata = IS.TimeSeriesDataMetadata("val", ta, IS.get_val)
    IS.add_time_series!(data, component1, ts_metadata, ta)
    IS.add_time_series!(data, component2, ts_metadata, ta)

    return data
end

function get_all_time_series(data)
    return collect(IS.get_time_series_multiple(data))
end

function create_time_array()
    dates = collect(
        Dates.DateTime("1/1/2020 00:00:00", "d/m/y H:M:S"):Dates.Hour(1):Dates.DateTime(
            "1/1/2020 23:00:00",
            "d/m/y H:M:S",
        ),
    )
    data = collect(1:24)
    component_name = "gen"
    ta = TimeSeries.TimeArray(dates, data, [component_name])
    return IS.TimeArrayWrapper(ta)
end
