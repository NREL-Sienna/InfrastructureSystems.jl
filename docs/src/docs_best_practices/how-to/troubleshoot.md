# Troubleshoot Common Errors

## [`Error: ## docstrings not included in the manual`](@id miss_doc)

**Problem**: Docstrings have been written, but have not been properly mapped to either a
public or internal API. There may be multiple issues:

1. Verify there is an Internal API file to catch doctrings for structs/functions that are
    not exported.
    [Example here](https://github.com/NREL-Sienna/SiennaTemplate.jl/blob/main/docs/src/reference/internal.md)
1. Identify the `*.jl` file for one of your missing docstrings. Are other docstrings in that file
    visible in the API?
    - If yes, check whether those other docstrings are listed in the API in a `@docs` block and
        [switch to `@autodocs`](@ref use_autodocs) with the `*.jl` file as one of its `Pages`
        instead. 
    - If no, add a new [`@autodocs` block](@extref) in the Public API with that `*.jl` file
        as one of its `Pages`.
    - Iterate through the missing docstrings to find other missing `*.jl` files.
1. Are these docstrings from `InfrastructureSystems.jl`? Follow how-to
    [selectively export docstrings from `InfrastructureSystems.jl`](@ref docs_from_is).

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

**Problem**: `JuliaFormatter` 1.0 typically errors on a single bracket in
the markdown, with an uninformative error message. Example:
```julia
] add PowerSystems
```

Workarounds:
- Avoid the single bracket with alternatives:
```julia
using Pkg; Pkg.add(["PowerSystems"])
```
- If you can't avoid it:
    1. Remove the text with single bracket temporarily
    2. Run the formatter once to format the rest of the file
    3. Add the text back in
    4. Add the `ignore` keyword argument with the file name to
        [`JuliaFormatter.format`](@extref `JuliaFormatter.format-Tuple{Any}`) in `scripts/formatter/formatter_code.jl`
        to skip the file in the future:
```julia
ignore = ["problem-file.md"],
```
You might need to iterate through multiple files.