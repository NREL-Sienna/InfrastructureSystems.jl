
import JSON2

function validate_serialization(sys::IS.SystemData)
    #path, io = mktemp()
    # For some reason files aren't getting deleted when written to /tmp. Using current dir.
    path = "test_system_serialization.json"
    io = open(path, "w")
    @info "Serializing to $path"

    try
        IS.prepare_for_serialization!(sys, path)
        IS.to_json(io, sys)
    catch
        close(io)
        rm(path)
        rethrow()
    end
    close(io)

    ts_file = nothing
    try
        ts_file = open(path) do file
            JSON2.read(file).time_series_storage_file
        end
        sys2 = IS.SystemData(path)
        return IS.compare_values(sys, sys2)
    finally
        @debug "delete temp file" path
        rm(path)
        rm(ts_file)
    end
end

@testset "Test JSON serialization of system data" begin
    for in_memory in (true, false)
        sys = create_system_data(; with_forecasts=true, time_series_in_memory=in_memory)
        @test validate_serialization(sys)
        text = JSON2.write(sys)
        @test length(text) > 0
    end
end

@testset "Test prepare_for_serialization" begin
    sys = create_system_data(; with_forecasts=true)
    IS.prepare_for_serialization!(sys, joinpath("dir1", "dir2", "sys.json"))
    @test sys.time_series_storage_file == joinpath("dir1", "dir2",
                                                   "sys_" * IS.TIME_SERIES_STORAGE_FILE)
end
