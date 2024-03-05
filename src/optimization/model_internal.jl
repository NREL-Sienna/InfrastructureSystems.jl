mutable struct ModelInternal{T <: AbstractOptimizationContainer}
    container::T
    ic_model_container::Union{Nothing, T}
    status::BuildStatus
    base_conversion::Bool
    executions::Int
    execution_count::Int
    output_dir::Union{Nothing, String}
    time_series_cache::Dict{TimeSeriesCacheKey, <:TimeSeriesCache}
    recorders::Vector{Symbol}
    console_level::Base.CoreLogging.LogLevel
    file_level::Base.CoreLogging.LogLevel
    store_parameters::Union{Nothing, AbstractModelStoreParams}
    ext::Dict{String, Any}
end

function ModelInternal(
    container::T;
    ext = Dict{String, Any}(),
    recorders = [],
) where {T <: AbstractOptimizationContainer}
    return ModelInternal{T}(
        container,
        nothing,
        BuildStatus.EMPTY,
        true,
        1, #Default executions is 1. The model will be run at least once
        0,
        nothing,
        nothing,
        Dict{TimeSeriesCacheKey, TimeSeriesCache}(),
        recorders,
        Logging.Warn,
        Logging.Info,
        nothing,
        ext,
    )
end

function add_recorder!(internal::ModelInternal, recorder::Symbol)
    push!(internal.recorders, recorder)
    return
end

get_recorders(internal::ModelInternal) = internal.recorders

function configure_logging(internal::ModelInternal, file_name, file_mode)
    return configure_logging(;
        console = true,
        console_stream = stderr,
        console_level = internal.console_level,
        file = true,
        filename = joinpath(internal.output_dir, file_name),
        file_level = internal.file_level,
        file_mode = file_mode,
        tracker = nothing,
        set_global = false,
    )
end
