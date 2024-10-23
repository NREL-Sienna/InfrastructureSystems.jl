# Requirements Checklist

## Code and Environment Requirements

The [`Sienna-Template`](https://github.com/NREL-Sienna/Sienna-Template) Git repo has the
required environments and formatting and documentation code. New Sienna packages should
start from this template.

Existing Sienna packages will need to be updated with these requirements, but these will
only need to be addressed once:

1. `docs/` environment must use [`Documenter.jl`](https://documenter.juliadocs.org/stable/)
    v1.0 or greater
    - That is, previous `compat` requirements of `Documenter = "0.27"` must be removed.
1. `docs/make.jl` file must call
    [`Documenter.makedocs`](https://documenter.juliadocs.org/stable/lib/public/#Documenter.makedocs)
    *without* the `warnonly` `kwarg` (i.e., all errors caught by `makedocs` must be resolved before
    merging). [See an example here](https://github.com/NREL-Sienna/InfrastructureSystems.jl/blob/768438a40c46767560891ec493cf87ed232a2b2b/docs/make.jl#L47).
1. The `scripts/formatter/formatter_code.jl` must be updated to format the markdown .md files in the
    `docs/` folder, calling `format`() with the `kwarg` `format_markdown = true`. See
    [these](https://github.com/NREL-Sienna/InfrastructureSystems.jl/blob/768438a40c46767560891ec493cf87ed232a2b2b/scripts/formatter/formatter_code.jl#L13)
    [three](https://github.com/NREL-Sienna/InfrastructureSystems.jl/blob/768438a40c46767560891ec493cf87ed232a2b2b/scripts/formatter/formatter_code.jl#L8)
    [links](https://github.com/NREL-Sienna/InfrastructureSystems.jl/blob/768438a40c46767560891ec493cf87ed232a2b2b/scripts/formatter/formatter_code.jl#L23)
    for examples of the updated lines. 

## Diataxis Requirements

1. Top-level documentation organization follows the [Diataxis](https://diataxis.fr/)
    framework (plus a welcome page/section)


!!! todo


## Pull Request Requirements

1. [Compile](@ref "Compile and View Documentation Locally") the documentation and look at
    it!

!!! todo