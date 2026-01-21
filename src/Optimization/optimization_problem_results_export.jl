"""
    struct OptimizationProblemResultsExport

Configuration for exporting optimization problem results to files.

Specifies which variables, duals, parameters, expressions, and auxiliary variables
should be exported when calling [`export_results`](@ref) on an
[`OptimizationProblemResults`](@ref) instance.

# Fields
- `name::Symbol`: Name identifier for this export configuration
- `duals::Set{ConstraintKey}`: Specific dual values to export
- `expressions::Set{ExpressionKey}`: Specific expression values to export
- `parameters::Set{ParameterKey}`: Specific parameter values to export
- `variables::Set{VariableKey}`: Specific variable values to export
- `aux_variables::Set{AuxVarKey}`: Specific auxiliary variable values to export
- `optimizer_stats::Bool`: Whether to export optimizer statistics
- `store_all_flags::Dict{Symbol, Bool}`: Flags indicating whether to export all values
  of each type (e.g., all variables, all duals). Set via constructor keyword arguments
  like `store_all_variables = true`. When a flag is true, all values of that type are
  exported regardless of what specific keys are passed in the corresponding set.

# Example
```julia
export_config = OptimizationProblemResultsExport(
    "MyExport";
    store_all_variables = true,
    store_all_duals = false,
    optimizer_stats = true,
)
export_results(results, export_config)
```

See also: [`OptimizationProblemResults`](@ref), [`export_results`](@ref)
"""
struct OptimizationProblemResultsExport
    name::Symbol
    duals::Set{ConstraintKey}
    expressions::Set{ExpressionKey}
    parameters::Set{ParameterKey}
    variables::Set{VariableKey}
    aux_variables::Set{AuxVarKey}
    optimizer_stats::Bool
    store_all_flags::Dict{Symbol, Bool}

    function OptimizationProblemResultsExport(
        name,
        duals,
        expressions,
        parameters,
        variables,
        aux_variables,
        optimizer_stats,
        store_all_flags,
    )
        duals = _check_fields(duals)
        expressions = _check_fields(expressions)
        parameters = _check_fields(parameters)
        variables = _check_fields(variables)
        aux_variables = _check_fields(aux_variables)
        new(
            name,
            duals,
            expressions,
            parameters,
            variables,
            aux_variables,
            optimizer_stats,
            store_all_flags,
        )
    end
end

function OptimizationProblemResultsExport(
    name;
    duals = Set{ConstraintKey}(),
    expressions = Set{ExpressionKey}(),
    parameters = Set{ParameterKey}(),
    variables = Set{VariableKey}(),
    aux_variables = Set{AuxVarKey}(),
    optimizer_stats = true,
    store_all_duals = false,
    store_all_expressions = false,
    store_all_parameters = false,
    store_all_variables = false,
    store_all_aux_variables = false,
)
    store_all_flags = Dict(
        :duals => store_all_duals,
        :expressions => store_all_expressions,
        :parameters => store_all_parameters,
        :variables => store_all_variables,
        :aux_variables => store_all_aux_variables,
    )
    return OptimizationProblemResultsExport(
        Symbol(name),
        duals,
        expressions,
        parameters,
        variables,
        aux_variables,
        optimizer_stats,
        store_all_flags,
    )
end

function _check_fields(fields)
    if !(typeof(fields) <: Set)
        fields = Set(fields)
    end

    return fields
end

should_export_dual(x::OptimizationProblemResultsExport, key) =
    _should_export(x, :duals, key)
should_export_expression(x::OptimizationProblemResultsExport, key) =
    _should_export(x, :expressions, key)
should_export_parameter(x::OptimizationProblemResultsExport, key) =
    _should_export(x, :parameters, key)
should_export_variable(x::OptimizationProblemResultsExport, key) =
    _should_export(x, :variables, key)
should_export_aux_variable(x::OptimizationProblemResultsExport, key) =
    _should_export(x, :aux_variables, key)

function _should_export(exports::OptimizationProblemResultsExport, field_name, key)
    exports.store_all_flags[field_name] && return true
    container = getproperty(exports, field_name)
    return key in container
end
