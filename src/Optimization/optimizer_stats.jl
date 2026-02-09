"""
    mutable struct OptimizerStats

Statistics and performance metrics from an optimization solver run.

Captures solver-reported metrics (termination status, objective value, solve time) as well as
timing information for auxiliary computations. Fields marked as `Union{Missing, T}` may not
be available for all solvers.

# Fields
- `detailed_stats::Bool`: Whether detailed statistics are available
- `objective_value::Float64`: Optimal objective function value
- `termination_status::Int`: Solver termination status code
- `primal_status::Int`: Status of the primal solution
- `dual_status::Int`: Status of the dual solution
- `solver_solve_time::Float64`: Time reported by the solver for the solve
- `result_count::Int`: Number of solutions found
- `has_values::Bool`: Whether primal values are available
- `has_duals::Bool`: Whether dual values are available
- `objective_bound::Union{Missing, Float64}`: Bound on the objective (for MIP solvers)
- `relative_gap::Union{Missing, Float64}`: Relative optimality gap (for MIP solvers)
- `dual_objective_value::Union{Missing, Float64}`: Dual objective value
- `solve_time::Float64`: Total solve time
- `barrier_iterations::Union{Missing, Int}`: Number of barrier iterations
- `simplex_iterations::Union{Missing, Int}`: Number of simplex iterations
- `node_count::Union{Missing, Int}`: Number of branch-and-bound nodes explored
- `timed_solve_time::Float64`: Externally timed solve duration
- `timed_calculate_aux_variables::Float64`: Time to calculate auxiliary variables
- `timed_calculate_dual_variables::Float64`: Time to calculate dual variables
- `solve_bytes_alloc::Union{Missing, Float64}`: Memory allocated during solve
- `sec_in_gc::Union{Missing, Float64}`: Time spent in garbage collection

See also: [`OptimizationProblemResults`](@ref)
"""
mutable struct OptimizerStats
    detailed_stats::Bool
    objective_value::Float64
    termination_status::Int
    primal_status::Int
    dual_status::Int
    solver_solve_time::Float64
    result_count::Int
    has_values::Bool
    has_duals::Bool
    # Candidate solution
    objective_bound::Union{Missing, Float64}
    relative_gap::Union{Missing, Float64}
    # Use missing instead of nothing so that CSV writting doesn't fail
    dual_objective_value::Union{Missing, Float64}
    # Work counters
    solve_time::Float64
    barrier_iterations::Union{Missing, Int}
    simplex_iterations::Union{Missing, Int}
    node_count::Union{Missing, Int}
    timed_solve_time::Float64
    timed_calculate_aux_variables::Float64
    timed_calculate_dual_variables::Float64
    solve_bytes_alloc::Union{Missing, Float64}
    sec_in_gc::Union{Missing, Float64}
end

function OptimizerStats()
    return OptimizerStats(
        false,
        NaN,
        -1,
        -1,
        -1,
        NaN,
        -1,
        false,
        false,
        missing,
        missing,
        missing,
        NaN,
        missing,
        missing,
        missing,
        NaN,
        0,
        0,
        missing,
        missing,
    )
end

"""
Construct OptimizerStats from a vector that was serialized.
"""
function OptimizerStats(data::Vector{Float64})
    vals = Vector(undef, length(data))
    to_missing = Set((
        :objective_bound,
        :dual_objective_value,
        :barrier_iterations,
        :simplex_iterations,
        :node_count,
        :solve_bytes_alloc,
        :sec_in_gc,
    ))
    for (i, name) in enumerate(fieldnames(OptimizerStats))
        if name in to_missing && isnan(data[i])
            vals[i] = missing
        else
            vals[i] = data[i]
        end
    end
    return OptimizerStats(vals...)
end

"""
Convert OptimizerStats to a matrix of floats that can be serialized.
"""
function to_matrix(stats::T) where {T <: OptimizerStats}
    field_values = Matrix{Float64}(undef, fieldcount(T), 1)
    for (ix, field) in enumerate(fieldnames(T))
        value = getproperty(stats, field)
        field_values[ix] = ismissing(value) ? NaN : value
    end
    return field_values
end

function to_dataframe(stats::OptimizerStats)
    df = DataFrames.DataFrame([to_namedtuple(stats)])
    return df
end

function to_dict(stats::OptimizerStats)
    data = Dict()
    for field in fieldnames(typeof(stats))
        data[String(field)] = getproperty(stats, field)
    end

    return data
end

function get_column_names(::Type{OptimizerStats})
    return (collect(string.(fieldnames(OptimizerStats))),)
end
