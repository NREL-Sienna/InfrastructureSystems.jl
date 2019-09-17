
import JSON2

function validate_serialization(sys::SystemData)
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
        sys2 = SystemData(path)
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
