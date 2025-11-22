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

# Getter functions for OptimizationProblemResultsExport
get_name(x::OptimizationProblemResultsExport) = x.name
get_duals_set(x::OptimizationProblemResultsExport) = x.duals
get_expressions_set(x::OptimizationProblemResultsExport) = x.expressions
get_parameters_set(x::OptimizationProblemResultsExport) = x.parameters
get_variables_set(x::OptimizationProblemResultsExport) = x.variables
get_aux_variables_set(x::OptimizationProblemResultsExport) = x.aux_variables
get_optimizer_stats_flag(x::OptimizationProblemResultsExport) = x.optimizer_stats
get_store_all_flags(x::OptimizationProblemResultsExport) = x.store_all_flags

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
    get_store_all_flags(exports)[field_name] && return true
    container = getproperty(exports, field_name)
    return key in container
end
