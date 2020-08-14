
import JSON2

function validate_serialization(sys::IS.SystemData; time_series_read_only = false)
    #path, io = mktemp()
    # For some reason files aren't getting deleted when written to /tmp. Using current dir.
    path = "test_system_serialization.json"
    @info "Serializing to $path"

    try
        if isfile(path)
            rm(path)
        end
        IS.prepare_for_serialization!(sys, path; force = true)
        IS.to_json(sys, path)
    catch
        rm(path)
        rethrow()
    end

    # Make sure the code supports the files changing directories.
    test_dir = mktempdir()
    path = mv(path, joinpath(test_dir, path))

    t_file = splitext(basename(path))[1] * "_" * IS.TIME_SERIES_STORAGE_FILE
    mv(t_file, joinpath(test_dir, t_file))
    v_file = splitext(basename(path))[1] * "_" * IS.VALIDATION_DESCRIPTOR_FILE
    mv(v_file, joinpath(test_dir, v_file))

    ts_file = open(path) do file
        JSON2.read(file).time_series_storage_file
    end
    sys2 = IS.SystemData(path; time_series_read_only = time_series_read_only)
    return sys2, IS.compare_values(sys, sys2)
end

@testset "Test JSON serialization of system data" begin
    for in_memory in (true, false)
        sys = create_system_data_shared_forecasts(; time_series_in_memory = in_memory)
        _, result = validate_serialization(sys)
        @test result
    end
end

@testset "Test prepare_for_serialization" begin
    sys = create_system_data_shared_forecasts()
    directory = joinpath("dir1", "dir2")
    IS.prepare_for_serialization!(sys, joinpath(directory, "sys.json"))
    @test IS.get_ext(sys.internal)["serialization_directory"] == directory
end

@testset "Test JSON serialization of with read-only time series" begin
    sys = create_system_data_shared_forecasts(; time_series_in_memory = false)
    sys2, result = validate_serialization(sys; time_series_read_only = true)
    @test result
    component = collect(IS.get_components(IS.TestComponent, sys2))[1]
    dates = collect(
        Dates.DateTime("2020-01-01T00:00:00"):Dates.Hour(1):Dates.DateTime("2020-01-01T23:00:00"),
    )
    data = collect(1:24)
    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    forecast = IS.Deterministic("get_val", ta)
    @test_throws ErrorException IS.add_forecast!(sys2, component, forecast)
    @test_throws ErrorException IS.clear_forecasts!(sys2)
    forecast = collect(IS.iterate_forecasts(component))[1]
    @test_throws ErrorException IS.remove_forecast!(
        IS.Deterministic,
        sys2,
        component,
        IS.get_initial_time(forecast),
        IS.get_label(forecast),
    )
end

@testset "Test JSON serialization of with mutable time series" begin
    sys = create_system_data_shared_forecasts(; time_series_in_memory = false)
    sys2, result = validate_serialization(sys; time_series_read_only = false)
    @test result
    IS.clear_forecasts!(sys2)

    sys2, result = validate_serialization(sys; time_series_read_only = false)
    @test result
    component = collect(IS.iterate_components_with_forecasts(sys2.components))[1]
    forecast = collect(IS.iterate_forecasts(component))[1]
    IS.remove_forecast!(
        IS.Deterministic,
        sys2,
        component,
        IS.get_initial_time(forecast),
        IS.get_label(forecast),
    )
    dates = collect(
        Dates.DateTime("2020-01-01T00:00:00"):Dates.Hour(1):Dates.DateTime("2020-01-01T23:00:00"),
    )
    data = collect(1:24)
    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    forecast = IS.Deterministic("get_val", ta)
    IS.add_forecast!(sys2, component, forecast)
end
