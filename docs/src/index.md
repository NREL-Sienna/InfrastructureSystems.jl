# InfrastructureSystems.jl

```@meta
CurrentModule = InfrastructureSystems
```

### Installation

The latest stable release of PowerSystems can be installed using the Julia package manager with

```Julia
] add InfrastructureSystems
```

For the current development version, "checkout" this package with

```Julia
] add InfrastructureSystems#master
```

### Overview

`InfrastructureSystems.jl` is a [`Julia`](http://www.julialang.org) package that utilities for
the packages in NREL's [SIIP Initiative](https://github.com/NREL-SIIP). This package is meant
for module development. It is used primarily by
[PowerSystems.jl](https://github.com/NREL-SIIP/PowerSystems.jl) and
[PowerSimulations.jl](https://github.com/NREL-SIIP/PowerSimulations.jl) but is
written to be extensible for other kinds of infrastructure models.

This document describes how to integrate it with other packages.

### Usage

`InfrastructureSystems.jl` does not export any method or struct by design. Please refer to
the [Style Guide](@ref style_guide).

For detailed use of `InfrastructureSystems.jl` visit the [API](@ref API_ref) section of the
documentation

`InfrastructureSystems.jl` provides several utilities for the development of packages:

```@contents
Pages = [
        "dev_tools/components_and_container.md",
        "dev_tools/auto_generation.md",
        "dev_tools/time_series.md",
        "dev_tools/recorder.md",
        "dev_tools/tests.md",
        "dev_tools/logging.md"
]
Depth = 2
```

------------
PowerSystems has been developed as part of the Scalable Integrated Infrastructure Planning
(SIIP) initiative at the U.S. Department of Energy's National Renewable Energy Laboratory
([NREL](https://www.nrel.gov/))
