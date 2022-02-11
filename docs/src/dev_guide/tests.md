# Running Tests

Unit tests can be executed in the REPL by executing the following:

```julia
julia> ] test
```

The unit test module supports several customizations to aid development and
debug. For instance, runnning a specific test file

  - Run a subset of tests in the REPL:

```julia
julia> push!(ARGS, "<test_filename_without_.jl>")
julia> include("test/runtests.jl")
```

  - Change logging level(s):

```julia
julia> IS.make_logging_config_file("logging_config.toml")
julia> ENV["SIIP_LOGGING_CONFIG"] = "logging_config.toml"
# Edit the file to suit your preferences.
julia> include("test/runtests.jl")
```

**Note** that you can filter out noisy log groups in this file.

The unit test module appends a summary of all log message counts to the log
file.  If a message is logged too frequently then consider tagging that message
with maxlog=X to suppress it.
