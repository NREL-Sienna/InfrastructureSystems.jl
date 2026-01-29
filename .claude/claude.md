package_role: utility_foundation
julia_compat: "^1.6"

design_objectives:
  primary: performance
  description: >
    Foundational library for performance-critical simulation packages.
    All code must be written with performance in mind.

  principles:
    - Elegance and concision in both interface and implementation
    - Fail fast with actionable error messages rather than hiding problems
    - Validate invariants explicitly in subtle cases
    - Avoid over-adherence to backwards compatibility for internal helpers

performance_requirements:
  priority: critical
  reference: https://docs.julialang.org/en/v1/manual/performance-tips/

  anti_patterns_to_avoid:
    type_instability:
      description: Functions must return consistent concrete types
      bad: "f(x) = x > 0 ? 1 : 1.0"
      good: "f(x) = x > 0 ? 1.0 : 1.0"
      check: "@code_warntype"

    abstract_field_types:
      description: Struct fields must have concrete types or be parameterized
      bad: "struct Foo; data::AbstractVector; end"
      good: "struct Foo{T<:AbstractVector}; data::T; end"

    untyped_containers:
      bad: "Vector{Any}(), Vector{Real}()"
      good: "Vector{Float64}(), Vector{Int}()"

    non_const_globals:
      bad: "THRESHOLD = 0.5"
      good: "const THRESHOLD = 0.5"

    unnecessary_allocations:
      patterns:
        - use views instead of copies (@view, @views)
        - pre-allocate arrays instead of push! in loops
        - use in-place operations (functions ending with !)

    captured_variables:
      description: Avoid closures that capture variables causing boxing
      solution: pass variables as function arguments instead

    splatting_penalty:
      description: Avoid splatting (...) in performance-critical code

    abstract_return_types:
      description: Avoid returning Union types or abstract types

  best_practices:
    - use @inbounds when bounds are verified
    - use broadcasting (dot syntax) for element-wise operations
    - avoid try-catch in hot paths
    - use function barriers to isolate type instability

  note: >
    Apply these guidelines with judgment. Not every function is performance-critical.
    Focus optimization efforts on hot paths and frequently called code.

file_structure:
  src/:
    key_files:
      - InfrastructureSystems.jl: main module and exports
      - system_data.jl: SystemData implementation
      - time_series_interface.jl: time series public API
      - component.jl: base component types
    subdirectories:
      - utils/: utility functions including generate_structs.jl
      - generated/: auto-generated struct files (DO NOT EDIT directly)
      - descriptors/: JSON descriptors for struct generation (structs.json)
      - Optimization/: optimization container types and results
      - Simulation/: simulation utilities
  test/: test suite
  docs/: documentation source
  scripts/: utility scripts (formatter)
  bin/: executable scripts (struct generation)

auto_generation:
  description: >
    Structs can be auto-generated from JSON descriptors using Mustache templates.
    Generated files are in src/generated/ and should NOT be edited directly.
  descriptor_file: src/descriptors/structs.json
  generator: src/utils/generate_structs.jl
  command: julia bin/generate_structs.jl src/descriptors/structs.json src/generated/
  workflow:
    - Edit the JSON descriptor file to define/modify struct fields
    - Run the generation command
    - Generated files include docstrings and constructors automatically

consumed_by:
  - PowerSystems.jl
  - PowerSimulations.jl
  - PowerSimulationsDynamics.jl
  - PowerNetworkMatrices.jl

core_abstractions:
  - InfrastructureSystemsComponent
  - InfrastructureSystemsType
  - InfrastructureSystemsContainer
  - SystemData
  - TimeSeriesData
  - ValueCurve
  - ProductionVariableCostCurve (CostCurve, FuelCurve)
  - FunctionData
  - ComponentSelector

test_patterns:
  location: test/
  runner: julia --project=test test/runtests.jl

code_conventions:
  style_guide_url: https://nrel-sienna.github.io/InfrastructureSystems.jl/stable/style/
  formatter:
    tool: JuliaFormatter
    command: julia -e 'include("scripts/formatter/formatter_code.jl")'
  key_rules:
    constructors: use function Foo() not Foo() = ...
    asserts: prefer InfrastructureSystems.@assert_op over @assert
    globals: UPPER_CASE for constants
    exports: all exports in main module file
    comments: complete sentences, describe why not how

documentation_practices:
  framework: Diataxis (https://diataxis.fr/)
  sienna_guide: https://nrel-sienna.github.io/InfrastructureSystems.jl/stable/docs_best_practices/explanation/

  docstring_requirements:
    scope: all elements of public interface (note IS is selective about exports)
    include: function signatures and arguments list
    automation: DocStringExtensions.TYPEDSIGNATURES (TYPEDFIELDS used sparingly in IS)
    see_also: add links for functions with same name (multiple dispatch)

  api_docs:
    public: docs/src/api/public.md using @autodocs with Public=true, Private=false
    internals: docs/src/api/internals.md

common_tasks:
  run_tests: julia --project=test test/runtests.jl
  build_docs: julia --project=docs docs/make.jl
  format_code: julia -e 'include("scripts/formatter/formatter_code.jl")'
  check_format: git diff --exit-code
  instantiate_test: julia --project=test -e 'using Pkg; Pkg.instantiate()'
  generate_structs: julia bin/generate_structs.jl src/descriptors/structs.json src/generated/

contribution_workflow:
  branch_naming: feature/description or fix/description (branches in main repo)
  main_branch: master
  pr_process:
    - Create a feature branch in the main repo
    - Make changes following the style guide
    - Run formatter before committing
    - Ensure tests pass
    - Submit pull request

troubleshooting:
  type_instability:
    symptom: Poor performance, many allocations
    diagnosis: "@code_warntype on suspect function"
    solution: See performance_requirements.anti_patterns_to_avoid

  formatter_fails:
    symptom: Formatter command returns error
    solution: julia -e 'include("scripts/formatter/formatter_code.jl")'

  test_failures:
    symptom: Tests fail unexpectedly
    solution: julia --project=test -e 'using Pkg; Pkg.instantiate()'

ai_agent_guidance:
  code_generation_priorities:
    - Performance matters - use concrete types in hot paths
    - Apply anti-patterns list with judgment (not exhaustively everywhere)
    - Run formatter on all changes
    - Add docstrings to public interface elements
    - Consider type stability in performance-critical functions

  when_modifying_code:
    - Read existing code patterns before making changes
    - Maintain consistency with existing style
    - Prefer failing fast with clear errors over silent failures
