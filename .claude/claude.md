# InfrastructureSystems.jl

**Package role:** Utility foundation library
**Julia compat:** ^1.6

## Overview

Foundational library for performance-critical simulation packages. For general Sienna coding practices, conventions, and performance guidelines, see [.claude/Sienna.md](.claude/Sienna.md).

This document covers InfrastructureSystems-specific aspects.

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

- **Location:** `test/`
- **Runner:** `julia --project=test test/runtests.jl`

## Common Tasks

| Task | Command |
|------|---------|
| Run tests | `julia --project=test test/runtests.jl` |
| Build docs | `julia --project=docs docs/make.jl` |
| Format code | `julia -e 'include("scripts/formatter/formatter_code.jl")'` |
| Check format | `git diff --exit-code` |
| Instantiate test env | `julia --project=test -e 'using Pkg; Pkg.instantiate()'` |
| Generate structs | `julia bin/generate_structs.jl src/descriptors/structs.json src/generated/` |

## AI Agent Guidance

**IMPORTANT:** Review [.claude/Sienna.md](.claude/Sienna.md) for general Sienna coding practices, performance requirements, and conventions.

### InfrastructureSystems-Specific Priorities

1. **Auto-generated files** — Never edit files in `src/generated/` directly. Modify `src/descriptors/structs.json` instead and run the generation command.
2. **Performance is critical** — This is a foundational library. Apply performance best practices rigorously in hot paths.
3. **Type stability** — Use `@code_warntype` to verify performance-critical functions.
4. **Avoid kwargs as much as possible** — Since InfrastructureSystems is a utility library consumed by other applications, avoid using `kwargs...` especially in functions that may be called in hot loops. Use explicit keyword arguments instead for better performance and type stability or avoid keyword arguments all together.
5. **Public API documentation** — Add docstrings to all public interface elements using `DocStringExtensions.TYPEDSIGNATURES`.
6. **Formatter** — Run `julia -e 'include("scripts/formatter/formatter_code.jl")'` on all changes.

### When Modifying Code

- Read existing code patterns before making changes
- Maintain consistency with existing style
- Prefer failing fast with clear errors over silent failures
- Consider impact on downstream packages (PowerSystems.jl, PowerSimulations.jl, etc.)
