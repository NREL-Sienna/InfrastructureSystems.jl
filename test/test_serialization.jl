
import JSON2

function validate_serialization(sys::IS.SystemData)
    path, io = mktemp()
    @info "Serializing to $path"

    try
        IS.to_json(io, sys)
    catch
        close(io)
        rm(path)
        rethrow()
    end
    close(io)

    try
        sys2 = IS.SystemData(path)
        return IS.compare_values(sys, sys2)
    finally
        @debug "delete temp file" path
        rm(path)
    end
end

@testset "Test JSON serialization of system data" begin
    sys = create_system_data(; with_forecasts=true)
    @test validate_serialization(sys)
    text = JSON2.write(sys)
    @test length(text) > 0
end

@testset "Test prepare_for_serialization" begin
    sys = create_system_data(; with_forecasts=true)
    IS.prepare_for_serialization!(sys, joinpath("dir1", "dir2", "sys.json"))
    @test sys.time_series_storage_file == joinpath("dir1", "dir2",
                                                   "sys_" * IS.TIME_SERIES_STORAGE_FILE)
end
