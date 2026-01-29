# InfrastructureSystems.jl

**Package role:** Utility foundation library
**Julia compat:** ^1.6

## Design Objectives

Foundational library for performance-critical simulation packages. All code must be written with performance in mind.

### Principles

- Elegance and concision in both interface and implementation
- Fail fast with actionable error messages rather than hiding problems
- Validate invariants explicitly in subtle cases
- Avoid over-adherence to backwards compatibility for internal helpers

## Performance Requirements

**Priority: Critical**
**Reference:** https://docs.julialang.org/en/v1/manual/performance-tips/

### Anti-Patterns to Avoid

**Type instability** — Functions must return consistent concrete types
- Bad: `f(x) = x > 0 ? 1 : 1.0`
- Good: `f(x) = x > 0 ? 1.0 : 1.0`
- Check: `@code_warntype`

**Abstract field types** — Struct fields must have concrete types or be parameterized
- Bad: `struct Foo; data::AbstractVector; end`
- Good: `struct Foo{T<:AbstractVector}; data::T; end`

**Untyped containers**
- Bad: `Vector{Any}()`, `Vector{Real}()`
- Good: `Vector{Float64}()`, `Vector{Int}()`

**Non-const globals**
- Bad: `THRESHOLD = 0.5`
- Good: `const THRESHOLD = 0.5`

**Unnecessary allocations**
- Use views instead of copies (`@view`, `@views`)
- Pre-allocate arrays instead of `push!` in loops
- Use in-place operations (functions ending with `!`)

**Captured variables** — Avoid closures that capture variables causing boxing. Pass variables as function arguments instead.

**Splatting penalty** — Avoid splatting (`...`) in performance-critical code.

**Abstract return types** — Avoid returning Union types or abstract types.

### Best Practices

- Use `@inbounds` when bounds are verified
- Use broadcasting (dot syntax) for element-wise operations
- Avoid `try-catch` in hot paths
- Use function barriers to isolate type instability

> Apply these guidelines with judgment. Not every function is performance-critical. Focus optimization efforts on hot paths and frequently called code.

## File Structure

### `src/`

Key files:
- `InfrastructureSystems.jl` — main module and exports
- `system_data.jl` — SystemData implementation
- `time_series_interface.jl` — time series public API
- `component.jl` — base component types

Subdirectories:
- `utils/` — utility functions including `generate_structs.jl`
- `generated/` — auto-generated struct files (**DO NOT EDIT directly**)
- `descriptors/` — JSON descriptors for struct generation (`structs.json`)
- `Optimization/` — optimization container types and results
- `Simulation/` — simulation utilities

### Other directories

- `test/` — test suite
- `docs/` — documentation source
- `scripts/` — utility scripts (formatter)
- `bin/` — executable scripts (struct generation)

## Auto-Generation

Structs can be auto-generated from JSON descriptors using Mustache templates. Generated files are in `src/generated/` and should **NOT** be edited directly.

- **Descriptor file:** `src/descriptors/structs.json`
- **Generator:** `src/utils/generate_structs.jl`
- **Command:** `julia bin/generate_structs.jl src/descriptors/structs.json src/generated/`

### Workflow

1. Edit the JSON descriptor file to define/modify struct fields
2. Run the generation command
3. Generated files include docstrings and constructors automatically

## Consumed By

- PowerSystems.jl
- PowerSimulations.jl
- PowerSimulationsDynamics.jl
- PowerNetworkMatrices.jl

## Core Abstractions

- `InfrastructureSystemsComponent`
- `InfrastructureSystemsType`
- `InfrastructureSystemsContainer`
- `SystemData`
- `TimeSeriesData`
- `ValueCurve`
- `ProductionVariableCostCurve` (`CostCurve`, `FuelCurve`)
- `FunctionData`
- `ComponentSelector`

## Test Patterns

- **Location:** `test/`
- **Runner:** `julia --project=test test/runtests.jl`

## Code Conventions

- **Style guide:** https://nrel-sienna.github.io/InfrastructureSystems.jl/stable/style/
- **Formatter:** JuliaFormatter — `julia -e 'include("scripts/formatter/formatter_code.jl")'`

### Key Rules

- **Constructors:** use `function Foo()` not `Foo() = ...`
- **Asserts:** prefer `InfrastructureSystems.@assert_op` over `@assert`
- **Globals:** `UPPER_CASE` for constants
- **Exports:** all exports in main module file
- **Comments:** complete sentences, describe why not how

## Documentation Practices

- **Framework:** [Diataxis](https://diataxis.fr/)
- **Sienna guide:** https://nrel-sienna.github.io/InfrastructureSystems.jl/stable/docs_best_practices/explanation/

### Docstring Requirements

- **Scope:** all elements of public interface (IS is selective about exports)
- **Include:** function signatures and arguments list
- **Automation:** `DocStringExtensions.TYPEDSIGNATURES` (`TYPEDFIELDS` used sparingly)
- **See also:** add links for functions with same name (multiple dispatch)

### API Docs

- **Public:** `docs/src/api/public.md` using `@autodocs` with `Public=true, Private=false`
- **Internals:** `docs/src/api/internals.md`

## Common Tasks

| Task | Command |
|------|---------|
| Run tests | `julia --project=test test/runtests.jl` |
| Build docs | `julia --project=docs docs/make.jl` |
| Format code | `julia -e 'include("scripts/formatter/formatter_code.jl")'` |
| Check format | `git diff --exit-code` |
| Instantiate test env | `julia --project=test -e 'using Pkg; Pkg.instantiate()'` |
| Generate structs | `julia bin/generate_structs.jl src/descriptors/structs.json src/generated/` |

## Contribution Workflow

- **Branch naming:** `feature/description` or `fix/description` (branches in main repo)
- **Main branch:** `master`

### PR Process

1. Create a feature branch in the main repo
2. Make changes following the style guide
3. Run formatter before committing
4. Ensure tests pass
5. Submit pull request

## Troubleshooting

**Type instability**
- Symptom: Poor performance, many allocations
- Diagnosis: `@code_warntype` on suspect function
- Solution: See anti-patterns above

**Formatter fails**
- Symptom: Formatter command returns error
- Solution: `julia -e 'include("scripts/formatter/formatter_code.jl")'`

**Test failures**
- Symptom: Tests fail unexpectedly
- Solution: `julia --project=test -e 'using Pkg; Pkg.instantiate()'`

## AI Agent Guidance

### Code Generation Priorities

1. Performance matters — use concrete types in hot paths
2. Apply anti-patterns list with judgment (not exhaustively everywhere)
3. Run formatter on all changes
4. Add docstrings to public interface elements
5. Consider type stability in performance-critical functions

### When Modifying Code

- Read existing code patterns before making changes
- Maintain consistency with existing style
- Prefer failing fast with clear errors over silent failures
