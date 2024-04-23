"""
Common structure to keep track of optimization models' internal information.
"""
mutable struct ModelInternal{T <: AbstractOptimizationContainer}
    container::T
    initial_conditions_model_container::Union{Nothing, T}
    status::ModelBuildStatus
    base_conversion::Bool
    executions::Int
    execution_count::Int
    output_dir::Union{Nothing, String}
    time_series_cache::Dict{TimeSeriesCacheKey, <:TimeSeriesCache}
    recorders::Vector{Symbol}
    console_level::Base.CoreLogging.LogLevel
    file_level::Base.CoreLogging.LogLevel
    store_params::Union{Nothing, AbstractModelStoreParams}
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
        ModelBuildStatus.EMPTY,
        true,
        1, #Default executions is 1. The model will be run at least once
        0,
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

get_container(internal::ModelInternal) = internal.container
get_recorders(internal::ModelInternal) = internal.recorders
get_store_params(internal::ModelInternal) = internal.store_params
get_status(internal::ModelInternal) = internal.status
get_constraints(internal::ModelInternal) = internal.container.constraints
get_execution_count(internal::ModelInternal) = internal.execution_count
get_executions(internal::ModelInternal) = internal.executions
get_initial_conditions_model_container(internal::ModelInternal) =
    internal.initial_conditions_model_container
get_optimization_container(internal::ModelInternal) = internal.container
get_output_dir(internal::ModelInternal) = internal.output_dir
get_time_series_cache(internal::ModelInternal) = internal.time_series_cache

set_container!(internal::ModelInternal, val) = internal.container = val
set_store_params!(internal::ModelInternal, store_params) =
    internal.store_params = store_params
set_console_level!(internal::ModelInternal, val) = internal.console_level = val
set_file_level!(internal::ModelInternal, val) = internal.file_level = val

set_executions!(internal::ModelInternal, val::Int) = internal.executions = val
set_execution_count!(internal::ModelInternal, val::Int) = internal.execution_count = val

function set_initial_conditions_model_container!(
    internal::ModelInternal,
    val::Union{Nothing, AbstractOptimizationContainer},
)
    internal.initial_conditions_model_container = val
    return
end

function set_status!(internal::ModelInternal, status::ModelBuildStatus)
    internal.status = status
    return
end

set_output_dir!(internal::ModelInternal, path::AbstractString) = internal.output_dir = path
set_store_params!(internal::ModelInternal, store_params::AbstractModelStoreParams) =
    internal.store_params = store_params

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
