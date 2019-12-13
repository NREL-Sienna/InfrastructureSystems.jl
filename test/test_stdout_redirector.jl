@testset "Test stdout redirector" begin
    log_file, io = mktemp()
    close(io)
    try
        IS.open_file_logger(log_file) do file_logger
            multi_logger = IS.MultiLogger([file_logger], IS.LogEventTracker())
            count = 3
            Logging.with_logger(multi_logger) do
                IS.redirect_stdout_to_log() do
                    for i in 1:count
                        message = "hello"
                        println("$message $i\n$message $i")
                        sleep(.01)
                    end
                end
            end
            events = IS.get_log_events(multi_logger.tracker, Logging.Info)
            @test length(events) == 1
            for event in events
                # There is one event per complete line.
                @test event.count == count * 2
            end
        end
    finally
        rm(log_file)
    end
end
