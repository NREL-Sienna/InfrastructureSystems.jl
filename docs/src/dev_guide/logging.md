# Logging

`InfrastructureSystems.jl` provides a `MultiLogger` object that allows customized
logging to console and file. Refer to the [logging
documentation](./logging.md).

If you want to create a package-specific log file during a simulation, consider
the workflow used by [PowerSimulations.jl](https://github.com/NREL-SIIP/PowerSimulations.jl). It creates a custom logger in its `build!(Simulation)` function and then uses
Julia's `Logging.with_logger` function to temporarily take over the global logger
during `build()` and `execute()`.

This document describes logging facilities available in the modules that use `InfrastructureSystems.jl`. The examples assume the following imports:

```Julia
import Logging
import InfrastructureSystems: configure_logging, open_file_logger, MultiLogger, LogEventTracker, make_logging_config_file
```

**Note**: Packages that depend on `InfrastructureSystems.jl` already re-export `configure_logging`, `open_file_logger`, `MultiLogger`, `LogEventTracker`

## Use Cases

### Enable logging in REPL or Jupyter Notebook

Use [`InfrastructureSystems.configure_logging`](@ref) to create a logger with your
preferences (console and/or file, levels, etc.).

**Note:** log messages are not automatically flushed to files. Call
`flush(logger)` to make this happen.

**Example**: Global logger configuration

```Julia
logger = configure_logging(; filename="log.txt")
@info "hello world"
flush(logger)
@error "some error"
close(logger)
```

You can also configure logging from a configuration file.

```julia
make_logging_config_file("logging_config.toml")
# Customize in an editor.
logger = configure_logging("logging_config.toml")
```

### Enable debug logging for code you are debugging but not for noisy areas you don't care about.

```julia
logger = configure_logging(console_level = Logging.Debug)
InfrastructureSystems.set_group_level!(logger, InfrastructureSystems.LOG_GROUP_TIME_SERIES)

# Or many at once.
InfrastructureSystems.set_group_levels!(
    logger,
    Dict(
        InfrastructureSystems.LOG_GROUP_SERIALIZATION => Logging.Info,
        InfrastructureSystems.LOG_GROUP_TIME_SERIES => Logging.Info,
    ),
)

# Get current settings
InfrastructureSystems.get_group_levels(logger)
InfrastructureSystems.get_group_level(logger, InfrastructureSystems.LOG_GROUP_TIME_SERIES)
```

### Log to console and file in an application or unit test environment

Create a `MultiLogger` from `Logging.ConsoleLogger` and `Logging.SimpleLogger`.
Use `open_file_logger` to guarantee that all messages get flushed to the file.

**Example** Multilogger configuration

```Julia
console_logger = ConsoleLogger(stderr, Logging.Error)

open_file_logger("log.txt", Logging.Info) do file_logger
    multi_logger = MultiLogger([console_logger, file_logger])
    global_logger(multi_logger)

    do_stuff()
end
```

**Note:** If someone may execute the code in the REPL then wrap that code in a
try/finally block and reset the global logger upon exit.

```Julia
function run_tests()
    console_logger = ConsoleLogger(stderr, Logging.Error)

    open_file_logger("log.txt", Logging.Info) do file_logger
        multi_logger = MultiLogger([console_logger, file_logger])
        global_logger(multi_logger)

        do_stuff()
    end
end

logger = global_logger()

try
    run_tests()
finally
    # Guarantee that the global logger is reset.
    global_logger(logger)
    nothing
end
```

### Suppress frequent messages

The standard Logging module in Julia provides a method to suppress messages.
Tag the log message with maxlog=X.

```Julia
for i in range(1, length=100)
    @error "something happened" i maxlog=2
end
```

Only 2 messages will get logged.

### Get a summary of log messages

By default a `MultiLogger` creates a `LogEventTracker` that keeps counts of all
messages. Call `report_log_summary` after execution.

```Julia
logger = configure_logging(; filename="log.txt")
@info "hello world"

# Include a summary in the log file.
@info report_log_summary(logger)
close(logger)
```

The output of the logger can ve explored in the REPL

```Julia
julia> for i in range(1, length=100)
           @info "hello" maxlog=2
           @warn "beware" maxlog=2
       end
julia> @info report_log_summary(logger)
┌ Info:
│ Log message summary:
│
│ 0 Error events:
│
│ 1 Warn events:
│   count=100 at REPL[19]:3
│     example message="beware"
│     suppressed=98
│
│ 1 Info events:
│   count=100 at REPL[19]:2
│     example message="hello"
└     suppressed=98
```
