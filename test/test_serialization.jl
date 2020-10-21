
function validate_serialization(sys::IS.SystemData; time_series_read_only = false)
    #path, io = mktemp()
    # For some reason files aren't getting deleted when written to /tmp. Using current dir.
    filename = "test_system_serialization.json"
    @info "Serializing to $filename"

    try
        if isfile(filename)
            rm(filename)
        end
        IS.prepare_for_serialization!(sys, filename; force = true)
        data = IS.serialize(sys)
        open(filename, "w") do io
            JSON3.write(io, data)
        end
    catch
        rm(filename)
        rethrow()
    end

    # Make sure the code supports the files changing directories.
    test_dir = mktempdir()
    path = mv(filename, joinpath(test_dir, filename))

    t_file = splitext(basename(path))[1] * "_" * IS.TIME_SERIES_STORAGE_FILE
    mv(t_file, joinpath(test_dir, t_file))
    v_file = splitext(basename(path))[1] * "_" * IS.VALIDATION_DESCRIPTOR_FILE
    mv(v_file, joinpath(test_dir, v_file))

    ts_file = open(path) do file
        JSON3.read(file, Dict)["time_series_storage_file"]
    end

    data = open(path) do io
        JSON3.read(io, Dict)
    end

    orig = pwd()
    try
        cd(dirname(path))
        sys2 = IS.deserialize(
            IS.SystemData,
            data;
            time_series_read_only = time_series_read_only,
        )
        return sys2, IS.compare_values(sys, sys2)
    finally
        cd(orig)
    end
end

@testset "Test JSON serialization of system data" begin
    for in_memory in (true, false)
        sys = create_system_data_shared_time_series(; time_series_in_memory = in_memory)
        _, result = validate_serialization(sys)
        @test result
    end
end

@testset "Test prepare_for_serialization" begin
    sys = create_system_data_shared_time_series()
    directory = joinpath(mktempdir(), "dir2")
    IS.prepare_for_serialization!(sys, joinpath(directory, "sys.json"))
    @test IS.get_ext(sys.internal)["serialization_directory"] == directory
end

@testset "Test JSON serialization of with read-only time series" begin
    sys = create_system_data_shared_time_series(; time_series_in_memory = false)
    sys2, result = validate_serialization(sys; time_series_read_only = true)
    @test result
end

@testset "Test JSON serialization of with mutable time series" begin
    sys = create_system_data_shared_time_series(; time_series_in_memory = false)
    sys2, result = validate_serialization(sys; time_series_read_only = false)
    @test result
end

@testset "Test verion info" begin
    data = IS.serialize_julia_info()
    @test haskey(data, "julia_version")
    @test haskey(data, "package_info")
end
