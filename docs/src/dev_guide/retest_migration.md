# Migrating Tests to ReTest.jl

This guide describes how to migrate a test suite from the traditional `Test.jl` pattern
to `ReTest.jl`, which enables interactive test execution and selective test running.

## Why ReTest.jl?

ReTest.jl provides several advantages over the standard Test.jl workflow:

  - Run subsets of tests using regular expressions
  - Faster iteration during development (no need to restart Julia)
  - Works with Revise.jl for automatic test reloading
  - Compatible with standard `] test` execution

## Key Migration Steps

### 1. Create a Separate Test Module

The most important structural change is wrapping all tests in a dedicated module. This
module encapsulates the test environment and makes tests reloadable.

Create a file like `test/MyPackageTests.jl`:

```julia
module MyPackageTests

using ReTest  # IMPORTANT: Must be at the top, before other imports
using Logging
# other imports

import MyPackage

# Include supporting files
include("common.jl")
include("test_helpers.jl")

# Include all test files
for filename in readdir(joinpath(@__DIR__))
    if startswith(filename, "test_") && endswith(filename, ".jl")
        include(filename)
    end
end

function run_tests(args...; kwargs...)
    # Setup logging, run tests, cleanup
    @time retest(args...; kwargs...)
end

export run_tests

end

using .MyPackageTests
```

### 2. Import Order Matters

**Critical**: `using ReTest` must appear at the top of your test module, before other
imports. ReTest.jl needs to be loaded first so that its `@testset` macro is available
when test files are included.

```julia
module MyPackageTests

using ReTest  # First!
using Logging
using SomeOtherPackage

end
```

If you import ReTest after other packages that use `@testset`, you may get unexpected
behavior or errors.

### 3. Include All Test Files in the Module

The module must include all test files so they become part of the module's scope. A
common pattern is to automatically discover and include files:

```julia
for filename in readdir(joinpath(BASE_DIR, "test"))
    if startswith(filename, "test_") && endswith(filename, ".jl")
        include(filename)
    end
end
```

You can also include files explicitly if you need control over the order:

```julia
include("test_core.jl")
include("test_utils.jl")
include("test_integration.jl")
```

### 4. Define and Export `run_tests`

The module should define a `run_tests` function that wraps `retest()` and handles any
setup/teardown (like logging configuration). This function should forward arguments to
`retest()` to enable pattern matching:

```julia
function run_tests(args...; kwargs...)
    # Optional: setup logging
    @time retest(args...; kwargs...)
    # Optional: cleanup
end

export run_tests
```

The export makes `run_tests` available after `using .MyPackageTests`.

### 5. Update runtests.jl

The main `test/runtests.jl` file becomes minimal:

```julia
using MyPackage

include("MyPackageTests.jl")
run_tests()
```

## Comparison: Before and After

### Before (Traditional Test.jl Pattern)

```julia
# test/runtests.jl
include("includes.jl")

const DISABLED_TEST_FILES = [
# "test_foo.jl",
]

macro includetests(testarg...)
    # Complex macro to discover and include test files
end

function run_tests()
    @time @testset "Begin MyPackage tests" begin
        @includetests ARGS
    end
end

run_tests()
```

Issues with this approach:

  - Cannot easily run a subset of tests interactively
  - Must restart Julia to pick up test changes
  - The `@includetests` macro adds complexity

### After (ReTest.jl Pattern)

```julia
# test/MyPackageTests.jl
module MyPackageTests

using ReTest
# other imports

# Include all test files
for filename in readdir(joinpath(@__DIR__))
    if startswith(filename, "test_") && endswith(filename, ".jl")
        include(filename)
    end
end

function run_tests(args...; kwargs...)
    @time retest(args...; kwargs...)
end

export run_tests

end

using .MyPackageTests
```

```julia
# test/runtests.jl
using MyPackage

include("MyPackageTests.jl")
run_tests()
```

## Interactive Development Setup

For interactive test development, create a `test/load_tests.jl` file:

```julia
using Revise

function recursive_includet(filename)
    already_included = copy(Revise.included_files)
    includet(filename)
    newly_included = setdiff(Revise.included_files, already_included)
    for (mod, file) in newly_included
        Revise.track(mod, file)
    end
end

recursive_includet("MyPackageTests.jl")
```

Then in the REPL:

```
julia> using TestEnv
julia> TestEnv.activate()
julia> include("test/load_tests.jl")
julia> run_tests()                    # Run all tests
julia> run_tests(r"test.*foo")        # Run tests matching pattern
```

See [Running Tests](tests.md) for more details on interactive test execution.
