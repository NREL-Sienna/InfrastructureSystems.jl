# Organize APIs and Write Docstrings

Docstrings for all structs, methods, and functions belong in the public or internal APIs,
organized under the [Reference](https://diataxis.fr/reference/) section in Diataxis organization.
Refer to this page particularly while editing Sienna docstrings and APIs for
guidance on common problems in our existing documentation.

## Prepare

- If you have not read [Diataxis](https://diataxis.fr/), first read it in its entirety.
- Refer back to the Diataxis [Reference](https://diataxis.fr/reference/) section while
    working.
- Read and follow Julia's guidance on [Writing Documentation](@extref),
    which mainly applies to docstrings
- Read the sections on `Documenter.jl`'s [`@docs` block](@extref) and
    [`@autodocs` block](@extref), and follow the guidance below on using `@autodocs`
    wherever possible     

## Follow the Do's and Don't's

Julia and `Documenter.jl`'s guidance above should be your main reference, but in addition,
follow these do's and don't to avoid common pitfalls from previous versions of Sienna
documentation:

```@contents
Pages = ["write_docstrings_org_api.md"]
Depth = 3:3
```

### Ensure All Docstrings Are Located in the APIs

!!! tip "Do"
    Include a Public API for exported structs, functions, and methods, and an Internals API
    for private functions. See
    [`PowerSystems.jl`](https://nrel-sienna.github.io/PowerSystems.jl/stable/)
    for an example with a Public API organized with `@autodocs` ([see next](@ref use_autodocs))
    or [`SiennaTemplate.jl`](https://github.com/NREL-Sienna/SiennaTemplate.jl) for a basic
    template when starting a new package.

!!! tip "Do"
    Migrate all existing Formulation Libraries and Model Libraries into the Public API. 

!!! tip "Do"
    If you want to make a docstring visible outside of the API (e.g., in a tutorial), use
    a [non-canonical reference](@extref noncanonical-block). 

### [Automate Updating the Docstrings in the API with `@autodocs`](@id use_autodocs)

!!! tip "Do"
    Use [`@autodocs` block](@extref)s in the Public API to automatically find all
    docstrings in a file. Example:
    ````markdown
    ## Variables
    ```@autodocs
    Modules = [SomeSiennaPackage]
    Pages = ["variables.jl"]
    Public = true
    Private = false
    ```
    ````

!!! warning "Don't"
    Manually list out the struts or methods on a topic in a [`@docs` block](@extref),
    because that introduces more work whenever we add something new or make a change.
    Example:
    ````markdown
    ## Variables
    ```@docs
    variable1
    variable2
    ```
    ````
    Consider re-organizing code if need be, so all related functions are in the same file(s)
    (e.g., `variables.jl`).

### [Selectively Export Docstrings from `InfrastructureSystems.jl`](@id docs_from_is)

If you are working in another Sienna package (e.g., `SomeSiennaPackage.jl`) that imports and
exports code from `InfrastructureSystems.jl`: 

!!! tip "Do"
    List the files containing necessary `InfrastructureSystems.jl` structs and methods in
    `SomeSiennaPackage.jl`'s Public API, then explicitly filter by what
    `SomeSiennaPackage.jl` exports. Example:

    ````markdown
    ```@autodocs
    Modules = [InfrastructureSystems]
    Pages   = ["production_variable_cost_curve.jl", # examples
                "cost_aliases.jl",
            ]
    Order = [:type, :function]
    Filter = t -> nameof(t) in names(SomeSiennaPackage)
    ```
    ````

!!! warning "Don't"
    List `InfrastructureSystems` as one of the `modules` in [`Documenter.makedocs`](@extref).
    `Documenter.jl` will
    look to map **all** `InfrastructureSystems.jl` docstrings into the API, resulting in
    hundreds of [missing docstring](@ref miss_doc) errors. Example:

    ```julia
    makedocs(
    modules = [SomeSiennaPackage, InfrastructureSystems],
    format = Documenter.HTML(
        prettyurls = haskey(ENV, "GITHUB_ACTIONS"),
        size_threshold = nothing),
    sitename = "SomeSiennaPackage.jl",
    pages = Any[p for p in pages],
    )
    ```

### Ensure All Docstrings Have a Function Signature and Arguments List

!!! tip "Do"
    Check all docstrings have a function signature and detailed arguments list
    *visible in the API when you compile it*. Example:

    ![A docstring with function signature and args list](../../assets/comp_after.png)

!!! warning "Don't"
    Leave docstrings that just have a description unaddressed. Example:

    ![A single line docstring](../../assets/comp_before.png)



### Automate Updating Docstring Arguments Lists

# TODO EXAMPLES

!!! tip "Do"
    Use autodocs typed signatures to automatically compile arguments lists

!!! warning "Don't"
    Copy and paste arguments lists into the docstring, which opens opportunity for
    out-of-date errors from changes in the future.

### Extract Docstring Information from Other Types of Documentation

# TODO HERE

### Look at the compiled .html!
!!! tip "Do"
    - [Compile](@ref "Compile and View Documentation Locally") the tutorial regularly and
        look at it
    - Check method signatures and argument lists are formatted correctly 
