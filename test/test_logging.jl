
import InfrastructureSystems:
    increment_count!,
    LogEventSuppressionStats,
    LogSuppressionTracker,
    should_suppress!,
    get_log_events

TEST_MSG = "test log message"

@testset "Test LogEventTracker" begin
    levels = (Logging.Info, Logging.Warn, Logging.Error)
    tracker = IS.LogEventTracker(levels)

    events = (
        IS.LogEvent("file", 14, :id, TEST_MSG, Logging.Debug),
        IS.LogEvent("file", 14, :id, TEST_MSG, Logging.Info),
        IS.LogEvent("file", 14, :id, TEST_MSG, Logging.Warn),
        IS.LogEvent("file", 14, :id, TEST_MSG, Logging.Error),
    )

    for i in range(1, length = 2)
        for event in events
            increment_count!(tracker, event, false)
        end
    end

    @test length(IS.get_log_events(tracker, Logging.Debug)) == 0
    for level in levels
        test_events = collect(IS.get_log_events(tracker, level))
        @test length(test_events) == 1
        @test test_events[1].count == 2
    end

    text = IS.report_log_summary(tracker)
    @test !occursin("Debug", text)
    @test !occursin("suppressed", text)
    for level in ("Error", "Warn", "Info")
        @test occursin("1 $level event", text)
    end
end

@testset "Test MultiLogger with no event tracking" begin
    logger = IS.MultiLogger([
        TerminalLogger(devnull, Logging.Info),
        SimpleLogger(devnull, Logging.Debug),
    ])
    with_logger(logger) do
        @info TEST_MSG
    end

    @test_throws ErrorException IS.report_log_summary(logger)
end

@testset "Test MultiLogger with event tracking" begin
    levels = (Logging.Debug, Logging.Info, Logging.Warn, Logging.Error)
    logger = IS.MultiLogger(
        [TerminalLogger(devnull, Logging.Info), SimpleLogger(devnull, Logging.Debug)],
        IS.LogEventTracker(levels),
    )

    with_logger(logger) do
        for i in range(1, length = 2)
            @debug TEST_MSG
            @info TEST_MSG
            @warn TEST_MSG
            @error TEST_MSG maxlog = 1
        end
    end

    events = collect(IS.get_log_events(logger.tracker, Logging.Error))
    @test length(events) == 1
    events[1].suppressed == 1

    text = IS.report_log_summary(logger)
    for level in levels
        @test occursin("1 $level event", text)
    end
end

@testset "Test configure_logging" begin
    # Verify logging to a file.
    logfile = "testlog.txt"
    logger = IS.configure_logging(;
        file = true,
        filename = logfile,
        file_level = Logging.Info,
        set_global = false,
    )
    with_logger(logger) do
        @info TEST_MSG
    end

    close(logger)

    @test isfile(logfile)
    open(logfile) do io
        lines = readlines(io)
        @test length(lines) == 2  # two lines per message
        @test occursin(TEST_MSG, lines[1])
    end
    rm(logfile)

    # Verify logging with no file.
    logger = IS.configure_logging(;
        console = true,
        file = false,
        console_stream = devnull,
        filename = nothing,
        file_level = Logging.Info,
        set_global = false,
    )
    with_logger(logger) do
        @error TEST_MSG
    end

    events = collect(IS.get_log_events(logger.tracker, Logging.Error))
    @test length(events) == 1
    close(logger)

    @test !isfile(logfile)

    # Verify disabling of tracker.
    logger = IS.configure_logging(;
        console = true,
        file = false,
        console_stream = devnull,
        filename = logfile,
        file_level = Logging.Info,
        set_global = false,
        tracker = nothing,
    )
    with_logger(logger) do
        @error TEST_MSG
        @test isnothing(logger.tracker)
    end

    # Verify setting of global logger
    orig_logger = global_logger()
    logger = IS.configure_logging(;
        console = true,
        file = false,
        console_stream = devnull,
        filename = logfile,
        file_level = Logging.Info,
        set_global = true,
        tracker = nothing,
    )
    @error TEST_MSG
    @test orig_logger != global_logger()
    global_logger(orig_logger)
end

@testset "Test group level" begin
    levels = (Logging.Debug, Logging.Info, Logging.Warn, Logging.Error)
    tracker = IS.LogEventTracker(levels)
    logger = IS.MultiLogger([TerminalLogger(devnull, Logging.Debug)], tracker)
    IS.set_group_level!(logger, :test_group, Logging.Info)

    @test IS.get_group_level(logger, :test_group) == Logging.Info
    @test IS.get_group_level(logger, :not_stored) === nothing

    with_logger(logger) do
        @debug TEST_MSG _group = :test_group
    end
    @test length(IS.get_log_events(tracker, Logging.Debug)) == 0

    IS.empty_group_levels!(logger)
    with_logger(logger) do
        @debug TEST_MSG _group = :test_group
    end
    @test length(IS.get_log_events(tracker, Logging.Debug)) == 1
end

@testset "Test group levels" begin
    levels = (Logging.Debug, Logging.Info, Logging.Warn, Logging.Error)
    tracker = IS.LogEventTracker(levels)
    logger = IS.MultiLogger([TerminalLogger(devnull, Logging.Debug)], tracker)
    min_levels = Dict(:test_group => Logging.Warn)
    IS.set_group_levels!(logger, min_levels)
    @test IS.get_group_levels(logger) == min_levels
    with_logger(logger) do
        @info TEST_MSG _group = :test_group
    end
    @test length(IS.get_log_events(tracker, Logging.Info)) == 0

    IS.empty_group_levels!(logger)
    with_logger(logger) do
        @info TEST_MSG _group = :test_group
    end
    @test length(IS.get_log_events(tracker, Logging.Info)) == 1
end

@testset "Test make_logging_config_file" begin
    filename = joinpath(tempdir(), "logging_config.toml")
    try
        redirect_stdout(devnull) do
            IS.make_logging_config_file(filename)
            return IS.make_logging_config_file(filename, force = true)
        end
        @test IS.LoggingConfiguration(filename) isa IS.LoggingConfiguration
    finally
        isfile(filename) && rm(filename)
    end
end

@testset "Test log suppression for single event" begin
    event_id = :my_event
    cur_time = time()
    period = 10
    maxlog = 3
    stats = LogEventSuppressionStats(event_id, cur_time, period)
    @test !stats.is_tracking_active
    @test stats.period == period

    for i in 1:maxlog
        suppress, num = should_suppress!(stats, cur_time, maxlog)
        @test !suppress
        @test num == 0
        @test stats.is_tracking_active
    end

    suppress, num = should_suppress!(stats, cur_time, maxlog)
    @test suppress
    @test num == 1
    @test stats.is_suppression_enabled
    suppress, num = should_suppress!(stats, cur_time, maxlog)
    @test suppress
    @test num == 2

    # Fake a jump in time.
    stats.tracking_start_time -= period
    suppress, num = should_suppress!(stats, cur_time, maxlog)
    @test !suppress
    @test num == 2
    @test !stats.is_suppression_enabled
    @test stats.count == 1
    @test stats.num_suppressed == 0

    for i in 1:(maxlog - 1)
        suppress, num = should_suppress!(stats, cur_time, maxlog)
        @test !suppress
        @test num == 0
        @test stats.is_tracking_active
    end

    suppress, num = should_suppress!(stats, cur_time, maxlog)
    @test suppress
    @test num == 1
end

@testset "Test log suppression" begin
    levels = (Logging.Info, Logging.Warn, Logging.Error)
    tracker = IS.LogEventTracker(levels)
    logger = IS.MultiLogger(
        [TerminalLogger(devnull, Logging.Info), SimpleLogger(devnull, Logging.Debug)],
        tracker,
    )

    function run()
        @info TEST_MSG maxlog = 5 _suppression_period = 10
    end

    with_logger(logger) do
        for _ in 1:15
            run()
        end
    end

    log_events = values(get_log_events(tracker, Logging.Info))
    @test length(log_events) == 1
    log_event = first(log_events)
    @test log_event.count == 15
    @test log_event.suppressed == 10
end

@testset "Test log suppression logging of num_suppressed" begin
    io = IOBuffer()
    logger = IS.MultiLogger([TerminalLogger(io, Logging.Info)])

    function run()
        @info TEST_MSG maxlog = 1 _suppression_period = 5
    end

    with_logger(logger) do
        # Not suppressed
        run()
        # Suppressed
        run()
        # Fake a jump in time.
        for stats in values(logger.suppression_tracker.event_stats)
            stats.tracking_start_time -= 10
        end
        # Not suppressed
        return run()
    end

    count_occurrences(str, substr) = length(split(str, substr)) - 1

    output = String(take!(io))
    @test count_occurrences(output, TEST_MSG) == 2
    @test count_occurrences(output, "num_suppressed") == 1
    @test count_occurrences(output, "num_suppressed = 1") == 1
end
