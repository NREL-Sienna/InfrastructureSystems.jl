
import JSON2

function validate_serialization(sys::IS.SystemData)
    #path, io = mktemp()
    # For some reason files aren't getting deleted when written to /tmp. Using current dir.
    path = "test_system_serialization.json"
    @info "Serializing to $path"

    try
        if isfile(path)
            rm(path)
        end
        IS.prepare_for_serialization!(sys, path)
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
    sys2 = IS.SystemData(path)
    return IS.compare_values(sys, sys2)
end

@testset "Test JSON serialization of system data" begin
    for in_memory in (true, false)
        sys = create_system_data(; with_forecasts = true, time_series_in_memory = in_memory)
        @test validate_serialization(sys)
    end
end

@testset "Test prepare_for_serialization" begin
    sys = create_system_data(; with_forecasts = true)
    directory = joinpath("dir1", "dir2")
    IS.prepare_for_serialization!(sys, joinpath(directory, "sys.json"))
    @test IS.get_ext(sys.internal)["serialization_directory"] == directory
end
