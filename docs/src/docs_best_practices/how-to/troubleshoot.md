# Troubleshoot Common Errors

## [`Error: ## docstrings not included in the manual`](@id miss_doc)

TODO

1. Are these docstrings from `InfrastructureSystems.jl`? Follow how-to
    [selectively export docstrings from `InfrastructureSystems.jl`](@ref docs_from_is)

## `Error: duplicate docs found`

> **Example**: `Error: duplicate docs found for 'PowerSimulations.SimulationProblemResults' in src\reference\PowerSimulations.md`

**Problem**: The same `.jl` file has been found more than once by `Documenter.jl`, which matches
based on the end of a file path.

1. Determine which file the function is located in
    > **Example**: `simulation_problem_results.jl` for `PowerSimulations.SimulationProblemResults`
2. Check whether that file is listed more than once in an `@autodocs` `Pages` list in the API
    markdown file (e.g., `PowerSimulations.md` or `public.md`). Remove duplicates.
3. Also check for other files with the same partial ending in the `@autodocs` `Pages` lists.
    Specify more of that file path to distinguish it.
    > **Example**: Change `Pages = ["problem_results.jl"]` to `Pages = ["operation/problem_results.jl"]` 

## `Parsing error for input` from `JuliaFormatter`

TODO