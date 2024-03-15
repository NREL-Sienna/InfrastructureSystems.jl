# This needs renaming to avoid collision with the DecionModelResults/EmulationModelResults
mutable struct OptimizationProblemResults <: Results
    base_power::Float64
    timestamps::StepRange{Dates.DateTime, Dates.Millisecond}
    source_data::Union{Nothing, InfrastructureSystemsType}
    source_data_uuid::Base.UUID
    aux_variable_values::Dict{AuxVarKey, DataFrames.DataFrame}
    variable_values::Dict{VariableKey, DataFrames.DataFrame}
    dual_values::Dict{ConstraintKey, DataFrames.DataFrame}
    parameter_values::Dict{ParameterKey, DataFrames.DataFrame}
    expression_values::Dict{ExpressionKey, DataFrames.DataFrame}
    optimizer_stats::DataFrames.DataFrame
    optimization_container_metadata::OptimizationContainerMetadata
    model_type::String
    output_dir::String
end

list_aux_variable_keys(res::OptimizationProblemResults) =
    collect(keys(res.aux_variable_values))
list_aux_variable_names(res::OptimizationProblemResults) =
    encode_keys_as_strings(keys(res.aux_variable_values))
list_variable_keys(res::OptimizationProblemResults) = collect(keys(res.variable_values))
list_variable_names(res::OptimizationProblemResults) =
    encode_keys_as_strings(keys(res.variable_values))
list_parameter_keys(res::OptimizationProblemResults) = collect(keys(res.parameter_values))
list_parameter_names(res::OptimizationProblemResults) =
    encode_keys_as_strings(keys(res.parameter_values))
list_dual_keys(res::OptimizationProblemResults) = collect(keys(res.dual_values))
list_dual_names(res::OptimizationProblemResults) =
    encode_keys_as_strings(keys(res.dual_values))
list_expression_keys(res::OptimizationProblemResults) = collect(keys(res.expression_values))
list_expression_names(res::OptimizationProblemResults) =
    encode_keys_as_strings(keys(res.expression_values))
get_timestamps(res::OptimizationProblemResults) = res.timestamps
get_model_base_power(res::OptimizationProblemResults) = res.base_power
get_dual_values(res::OptimizationProblemResults) = res.dual_values
get_expression_values(res::OptimizationProblemResults) = res.expression_values
get_variable_values(res::OptimizationProblemResults) = res.variable_values
get_aux_variable_values(res::OptimizationProblemResults) = res.aux_variable_values
get_total_cost(res::OptimizationProblemResults) = get_objective_value(res)
get_optimizer_stats(res::OptimizationProblemResults) = res.optimizer_stats
get_parameter_values(res::OptimizationProblemResults) = res.parameter_values
get_resolution(res::OptimizationProblemResults) = res.timestamps.step
get_system(res::OptimizationProblemResults) = res.system
get_forecast_horizon(res::OptimizationProblemResults) = length(get_timestamps(res))

get_result_values(x::OptimizationProblemResults, ::AuxVarKey) = x.aux_variable_values
get_result_values(x::OptimizationProblemResults, ::ConstraintKey) = x.dual_values
get_result_values(x::OptimizationProblemResults, ::ExpressionKey) = x.expression_values
get_result_values(x::OptimizationProblemResults, ::ParameterKey) = x.parameter_values
get_result_values(x::OptimizationProblemResults, ::VariableKey) = x.variable_values

function get_objective_value(res::OptimizationProblemResults, execution = 1)
    return res.optimizer_stats[execution, :objective_value]
end

"""
Exports all results from the operations problem.
"""
function export_results(results::OptimizationProblemResults; kwargs...)
    exports = OptimizationProblemResultsExport(
        "Problem";
        store_all_duals = true,
        store_all_parameters = true,
        store_all_variables = true,
        store_all_aux_variables = true,
    )
    return export_results(results, exports; kwargs...)
end

function export_results(
    results::OptimizationProblemResults,
    exports::OptimizationProblemResultsExport;
    file_type = CSV.File,
)
    file_type != CSV.File && error("only CSV.File is currently supported")
    export_path = mkpath(joinpath(results.output_dir, "variables"))
    for (key, df) in results.variable_values
        if should_export_variable(exports, key)
            export_result(file_type, export_path, key, df)
        end
    end

    export_path = mkpath(joinpath(results.output_dir, "aux_variables"))
    for (key, df) in results.aux_variable_values
        if should_export_aux_variable(exports, key)
            export_result(file_type, export_path, key, df)
        end
    end

    export_path = mkpath(joinpath(results.output_dir, "duals"))
    for (key, df) in results.dual_values
        if should_export_dual(exports, key)
            export_result(file_type, export_path, key, df)
        end
    end

    export_path = mkpath(joinpath(results.output_dir, "parameters"))
    for (key, df) in results.parameter_values
        if should_export_parameter(exports, key)
            export_result(file_type, export_path, key, df)
        end
    end

    export_path = mkpath(joinpath(results.output_dir, "expressions"))
    for (key, df) in results.expression_values
        if should_export_expression(exports, key)
            export_result(file_type, export_path, key, df)
        end
    end

    if exports.optimizer_stats
        export_result(
            file_type,
            joinpath(results.output_dir, "optimizer_stats.csv"),
            results.optimizer_stats,
        )
    end

    @info "Exported OptimizationProblemResults to $(results.output_dir)"
end

function _deserialize_key(
    ::Type{<:OptimizationContainerKey},
    results::OptimizationProblemResults,
    name::AbstractString,
)
    return deserialize_key(results.optimization_container_metadata, name)
end

function _deserialize_key(
    ::Type{T},
    ::OptimizationProblemResults,
    args...,
) where {T <: OptimizationContainerKey}
    return make_key(T, args...)
end

read_optimizer_stats(res::OptimizationProblemResults) = res.optimizer_stats

"""
Set the system in the results instance.

Throws InvalidValue if the source UUID is incorrect.
"""
function set_data_source!(
    res::OptimizationProblemResults,
    source::InfrastructureSystemsType,
)
    source_uuid = get_uuid(source)
    if source_uuid != res.source_uuid
        throw(
            InvalidValue(
                "System mismatch. $sys_uuid does not match the stored value of $(res.source_uuid)",
            ),
        )
    end

    res.source = source
    return
end

const _PROBLEM_RESULTS_FILENAME = "problem_results.bin"

"""
Serialize the results to a binary file.

It is recommended that `directory` be the directory that contains a serialized
OperationModel. That will allow automatic deserialization of the PowerSystems.System.
The `OptimizationProblemResults` instance can be deserialized with `OptimizationProblemResults(directory)`.
"""
function serialize_results(res::OptimizationProblemResults, directory::AbstractString)
    mkpath(directory)
    filename = joinpath(directory, _PROBLEM_RESULTS_FILENAME)
    isfile(filename) && rm(filename)
    Serialization.serialize(filename, _copy_for_serialization(res))
    @info "Serialize OptimizationProblemResults to $filename"
end

"""
Construct a OptimizationProblemResults instance from a serialized directory.

If the directory contains a serialized PowerSystems.System then it will deserialize that
system and add it to the results. Otherwise, it is up to the caller to call
[`set_system!`](@ref) on the returned instance to restore it.
"""
function OptimizationProblemResults(directory::AbstractString)
    filename = joinpath(directory, _PROBLEM_RESULTS_FILENAME)
    if !isfile(filename)
        error("No results file exists in $directory")
    end

    results = Serialization.deserialize(filename)
    possible_sys_file = joinpath(directory, make_system_filename(results.system_uuid))
    if isfile(possible_sys_file)
        set_system!(results, PSY.System(possible_sys_file))
    else
        @info "$directory does not contain a serialized System, skipping deserialization."
    end

    return results
end

function _copy_for_serialization(res::OptimizationProblemResults)
    return OptimizationProblemResults(
        res.base_power,
        res.timestamps,
        nothing,
        res.system_uuid,
        res.aux_variable_values,
        res.variable_values,
        res.dual_values,
        res.parameter_values,
        res.expression_values,
        res.optimizer_stats,
        res.optimization_container_metadata,
        res.model_type,
        res.output_dir,
    )
end

function _read_results(
    result_values::Dict{<:OptimizationContainerKey, DataFrames.DataFrame},
    container_keys,
    timestamps::Vector{Dates.DateTime},
    time_ids,
    base_power::Float64,
)
    existing_keys = keys(result_values)
    container_keys = container_keys === nothing ? existing_keys : container_keys
    _validate_keys(existing_keys, container_keys)
    results = Dict{OptimizationContainerKey, DataFrames.DataFrame}()
    for (k, v) in result_values
        if k in container_keys
            num_rows = DataFrames.nrow(v)
            if num_rows == 1 && num_rows < length(time_ids)
                results[k] =
                    if convert_result_to_natural_units(k)
                        v .* base_power
                    else
                        v
                    end
            else
                results[k] =
                    if convert_result_to_natural_units(k)
                        v[time_ids, :] .* base_power
                    else
                        v[time_ids, :]
                    end
                DataFrames.insertcols!(results[k], 1, :DateTime => timestamps)
            end
        end
    end
    return results
end

function _process_timestamps(
    res::OptimizationProblemResults,
    start_time::Union{Nothing, Dates.DateTime},
    len::Union{Int, Nothing},
)
    if start_time === nothing
        start_time = first(get_timestamps(res))
    elseif start_time ∉ get_timestamps(res)
        throw(InvalidValue("start_time not in result timestamps"))
    end

    if startswith(res.model_type, "EmulationModel{")
        def_len = DataFrames.nrow(get_optimizer_stats(res))
        requested_range =
            collect(findfirst(x -> x >= start_time, get_timestamps(res)):def_len)
        timestamps = repeat(get_timestamps(res), def_len)
    else
        timestamps = get_timestamps(res)
        requested_range = findall(x -> x >= start_time, timestamps)
        def_len = length(requested_range)
    end
    len = len === nothing ? def_len : len
    if len > def_len
        throw(InvalidValue("requested results have less than $len values"))
    end
    timestamp_ids = requested_range[1:len]
    return timestamp_ids, timestamps[timestamp_ids]
end

"""
Return the values for the requested variable key for a problem.
Accepts a vector of keys for the return of the values. If the time stamps and keys are
loaded using the [`load_results!`](@ref) function it will read from memory.

# Arguments

  - `variable::Tuple{Type{<:VariableType}, Type{<:PSY.Component}` : Tuple with variable type and device type for the desired results
  - `start_time::Dates.DateTime` : start time of the requested results
  - `len::Int`: length of results
"""
function read_variable(res::OptimizationProblemResults, args...; kwargs...)
    key = VariableKey(args...)
    return read_variable(res, key; kwargs...)
end

function read_variable(res::OptimizationProblemResults, key::AbstractString; kwargs...)
    return read_variable(res, _deserialize_key(VariableKey, res, key); kwargs...)
end

function read_variable(
    res::OptimizationProblemResults,
    key::VariableKey;
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Int, Nothing} = nothing,
)
    return read_results_with_keys(res, [key]; start_time = start_time, len = len)[key]
end

"""
Return the values for the requested variable keys for a problem.
Accepts a vector of keys for the return of the values. If the time stamps and keys are
loaded using the [`load_results!`](@ref) function it will read from memory.

# Arguments

  - `variables::Vector{Tuple{Type{<:VariableType}, Type{<:PSY.Component}}` : Tuple with variable type and device type for the desired results
  - `start_time::Dates.DateTime` : initial time of the requested results
  - `len::Int`: length of results
"""
function read_variables(res::OptimizationProblemResults, variables; kwargs...)
    return read_variables(res, [VariableKey(x...) for x in variables]; kwargs...)
end

function read_variables(
    res::OptimizationProblemResults,
    variables::Vector{<:AbstractString};
    kwargs...,
)
    return read_variables(
        res,
        [_deserialize_key(VariableKey, res, x) for x in variables];
        kwargs...,
    )
end

function read_variables(
    res::OptimizationProblemResults,
    variables::Vector{<:OptimizationContainerKey};
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Int, Nothing} = nothing,
)
    result_values =
        read_results_with_keys(res, variables; start_time = start_time, len = len)
    return Dict(encode_key_as_string(k) => v for (k, v) in result_values)
end

"""
Return the values for all variables.
"""
function read_variables(res::Results)
    return Dict(x => read_variable(res, x) for x in list_variable_names(res))
end

"""
Return the values for the requested dual key for a problem.
Accepts a vector of keys for the return of the values. If the time stamps and keys are
loaded using the [`load_results!`](@ref) function it will read from memory.

# Arguments

  - `dual::Tuple{Type{<:ConstraintType}, Type{<:PSY.Component}` : Tuple with dual type and device type for the desired results
  - `start_time::Dates.DateTime` : initial time of the requested results
  - `len::Int`: length of results
"""
function read_dual(res::OptimizationProblemResults, args...; kwargs...)
    key = ConstraintKey(args...)
    return read_dual(res, key; kwargs...)
end

function read_dual(res::OptimizationProblemResults, key::AbstractString; kwargs...)
    return read_dual(res, _deserialize_key(ConstraintKey, res, key); kwargs...)
end

function read_dual(
    res::OptimizationProblemResults,
    key::ConstraintKey;
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Int, Nothing} = nothing,
)
    return read_results_with_keys(res, [key]; start_time = start_time, len = len)[key]
end

"""
Return the values for the requested dual keys for a problem.
Accepts a vector of keys for the return of the values. If the time stamps and keys are
loaded using the [`load_results!`](@ref) function it will read from memory.

# Arguments

  - `duals::Vector{Tuple{Type{<:ConstraintType}, Type{<:PSY.Component}}` : Tuple with dual type and device type for the desired results
  - `start_time::Dates.DateTime` : initial time of the requested results
  - `len::Int`: length of results
"""
function read_duals(res::OptimizationProblemResults, duals; kwargs...)
    return read_duals(res, [ConstraintKey(x...) for x in duals]; kwargs...)
end

function read_duals(
    res::OptimizationProblemResults,
    duals::Vector{<:AbstractString};
    kwargs...,
)
    return read_duals(
        res,
        [_deserialize_key(ConstraintKey, res, x) for x in duals];
        kwargs...,
    )
end

function read_duals(
    res::OptimizationProblemResults,
    duals::Vector{<:OptimizationContainerKey};
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Int, Nothing} = nothing,
)
    result_values = read_results_with_keys(res, duals; start_time = start_time, len = len)
    return Dict(encode_key_as_string(k) => v for (k, v) in result_values)
end

"""
Return the values for all duals.
"""
function read_duals(res::Results)
    duals = Dict(x => read_dual(res, x) for x in list_dual_names(res))
end

"""
Return the values for the requested parameter key for a problem.
Accepts a vector of keys for the return of the values. If the time stamps and keys are
loaded using the [`load_results!`](@ref) function it will read from memory.

# Arguments

  - `parameter::Tuple{Type{<:ParameterType}, Type{<:PSY.Component}` : Tuple with parameter type and device type for the desired results
  - `start_time::Dates.DateTime` : initial time of the requested results
  - `len::Int`: length of results
"""
function read_parameter(res::OptimizationProblemResults, args...; kwargs...)
    key = ParameterKey(args...)
    return read_parameter(res, key; kwargs...)
end

function read_parameter(res::OptimizationProblemResults, key::AbstractString; kwargs...)
    return read_parameter(res, _deserialize_key(ParameterKey, res, key); kwargs...)
end

function read_parameter(
    res::OptimizationProblemResults,
    key::ParameterKey;
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Int, Nothing} = nothing,
)
    return read_results_with_keys(res, [key]; start_time = start_time, len = len)[key]
end

"""
Return the values for the requested parameter keys for a problem.
Accepts a vector of keys for the return of the values. If the time stamps and keys are
loaded using the [`load_results!`](@ref) function it will read from memory.

# Arguments

  - `parameters::Vector{Tuple{Type{<:ParameterType}, Type{<:PSY.Component}}` : Tuple with parameter type and device type for the desired results
  - `start_time::Dates.DateTime` : initial time of the requested results
  - `len::Int`: length of results
"""
function read_parameters(res::OptimizationProblemResults, parameters; kwargs...)
    return read_parameters(res, [ParameterKey(x...) for x in parameters]; kwargs...)
end

function read_parameters(
    res::OptimizationProblemResults,
    parameters::Vector{<:AbstractString};
    kwargs...,
)
    return read_parameters(
        res,
        [_deserialize_key(ParameterKey, res, x) for x in parameters];
        kwargs...,
    )
end

function read_parameters(
    res::OptimizationProblemResults,
    parameters::Vector{<:OptimizationContainerKey};
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Int, Nothing} = nothing,
)
    result_values =
        read_results_with_keys(res, parameters; start_time = start_time, len = len)
    return Dict(encode_key_as_string(k) => v for (k, v) in result_values)
end

"""
Return the values for all parameters.
"""
function read_parameters(res::Results)
    parameters = Dict(x => read_parameter(res, x) for x in list_parameter_names(res))
end

"""
Return the values for the requested aux_variable key for a problem.
Accepts a vector of keys for the return of the values. If the time stamps and keys are
loaded using the [`load_results!`](@ref) function it will read from memory.

# Arguments

  - `aux_variable::Tuple{Type{<:AuxVariableType}, Type{<:PSY.Component}` : Tuple with aux_variable type and device type for the desired results
  - `start_time::Dates.DateTime` : initial time of the requested results
  - `len::Int`: length of results
"""
function read_aux_variable(res::OptimizationProblemResults, args...; kwargs...)
    key = AuxVarKey(args...)
    return read_aux_variable(res, key; kwargs...)
end

function read_aux_variable(res::OptimizationProblemResults, key::AbstractString; kwargs...)
    return read_aux_variable(res, _deserialize_key(AuxVarKey, res, key); kwargs...)
end

function read_aux_variable(
    res::OptimizationProblemResults,
    key::AuxVarKey;
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Int, Nothing} = nothing,
)
    return read_results_with_keys(res, [key]; start_time = start_time, len = len)[key]
end

"""
Return the values for the requested aux_variable keys for a problem.
Accepts a vector of keys for the return of the values. If the time stamps and keys are
loaded using the [`load_results!`](@ref) function it will read from memory.

# Arguments

  - `aux_variables::Vector{Tuple{Type{<:AuxVariableType}, Type{<:PSY.Component}}` : Tuple with aux_variable type and device type for the desired results
  - `start_time::Dates.DateTime` : initial time of the requested results
  - `len::Int`: length of results
"""
function read_aux_variables(res::OptimizationProblemResults, aux_variables; kwargs...)
    return read_aux_variables(res, [AuxVarKey(x...) for x in aux_variables]; kwargs...)
end

function read_aux_variables(
    res::OptimizationProblemResults,
    aux_variables::Vector{<:AbstractString};
    kwargs...,
)
    return read_aux_variables(
        res,
        [_deserialize_key(AuxVarKey, res, x) for x in aux_variables];
        kwargs...,
    )
end

function read_aux_variables(
    res::OptimizationProblemResults,
    aux_variables::Vector{<:OptimizationContainerKey};
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Int, Nothing} = nothing,
)
    result_values =
        read_results_with_keys(res, aux_variables; start_time = start_time, len = len)
    return Dict(encode_key_as_string(k) => v for (k, v) in result_values)
end

"""
Return the values for all auxiliary variables.
"""
function read_aux_variables(res::Results)
    return Dict(x => read_aux_variable(res, x) for x in list_aux_variable_names(res))
end

"""
Return the values for the requested expression key for a problem.
Accepts a vector of keys for the return of the values. If the time stamps and keys are
loaded using the [`load_results!`](@ref) function it will read from memory.

# Arguments

  - `expression::Tuple{Type{<:ExpressionType}, Type{<:PSY.Component}` : Tuple with expression type and device type for the desired results
  - `start_time::Dates.DateTime` : initial time of the requested results
  - `len::Int`: length of results
"""
function read_expression(res::OptimizationProblemResults, args...; kwargs...)
    key = ExpressionKey(args...)
    return read_expression(res, key; kwargs...)
end

function read_expression(res::OptimizationProblemResults, key::AbstractString; kwargs...)
    return read_expression(res, _deserialize_key(ExpressionKey, res, key); kwargs...)
end

function read_expression(
    res::OptimizationProblemResults,
    key::ExpressionKey;
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Int, Nothing} = nothing,
)
    return read_results_with_keys(res, [key]; start_time = start_time, len = len)[key]
end

"""
Return the values for the requested expression keys for a problem.
Accepts a vector of keys for the return of the values. If the time stamps and keys are
loaded using the [`load_results!`](@ref) function it will read from memory.

# Arguments

  - `expressions::Vector{Tuple{Type{<:ExpressionType}, Type{<:PSY.Component}}` : Tuple with expression type and device type for the desired results
  - `start_time::Dates.DateTime` : initial time of the requested results
  - `len::Int`: length of results
"""
function read_expressions(res::OptimizationProblemResults; kwargs...)
    return read_expressions(res, collect(keys(res.expression_values)); kwargs...)
end

function read_expressions(res::OptimizationProblemResults, expressions; kwargs...)
    return read_expressions(res, [ExpressionKey(x...) for x in expressions]; kwargs...)
end

function read_expressions(
    res::OptimizationProblemResults,
    expressions::Vector{<:AbstractString};
    kwargs...,
)
    return read_expressions(
        res,
        [_deserialize_key(ExpressionKey, res, x) for x in expressions];
        kwargs...,
    )
end

function read_expressions(
    res::OptimizationProblemResults,
    expressions::Vector{<:OptimizationContainerKey};
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Int, Nothing} = nothing,
)
    result_values =
        read_results_with_keys(res, expressions; start_time = start_time, len = len)
    return Dict(encode_key_as_string(k) => v for (k, v) in result_values)
end

"""
Return the values for all expressions.
"""
function read_expressions(res::Results)
    return Dict(x => read_expression(res, x) for x in list_expression_names(res))
end

function read_results_with_keys(
    res::OptimizationProblemResults,
    result_keys::Vector{<:OptimizationContainerKey};
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Int, Nothing} = nothing,
)
    isempty(result_keys) && return Dict{OptimizationContainerKey, DataFrames.DataFrame}()
    (timestamp_ids, timestamps) = _process_timestamps(res, start_time, len)
    return _read_results(
        get_result_values(res, first(result_keys)),
        result_keys,
        timestamps,
        timestamp_ids,
        get_model_base_power(res),
    )
end

function export_realized_results(res::OptimizationProblemResults)
    save_path = mkpath(joinpath(res.output_dir, "export"))
    return export_realized_results(res, save_path)
end
