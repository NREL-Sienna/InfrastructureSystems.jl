# Write Docstrings and Organize the APIs

Docstrings for all structs, methods, and functions belong in the public or internal APIs,
organized under the [Reference](https://diataxis.fr/reference/) section in Diataxis organization.
Refer to this page particularly while editing existing Sienna docstrings and APIs for
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

Do: checj all dock strings have a function signature. (is there a more correct name for that?), Plus an additional arguments list if needed.
Don’t: leave strings That just have a description to remain unaddressed

Do: use auto docs typed signatures to automatically compile arguments lists
Don’t: copy and paste arguments lists into the doc string, which opens opportunity for out of date errors from changes in the future 

### 

Do: if you want to make a dock string visible outside of the API (e.g., in a tutorial), use non-canonical reference
Do: migrate all formulation library, and model libraries into the public API 

##

Do: use auto docs to automatically find all dock strings in a file
Don’t: manually list out the struts or methods within a topic, because that introduces more work whenever we make a change. Consider re-organizing code if need be, so all related functions are in the same file.

### [Selectively Export Docstrings from `InfrastructureSystems.jl`](@id docs_from_isz)

If you are working in another Sienna package (e.g., `SomeSiennaPackage.jl`) that imports and
exports code from `InfrastructureSystems.jl`: 

!!! tip "Do"
    List the files containing necessary `InfrastructureSystems.jl` structs and methods in
    `SomeSiennaPackage.jl`'s API, then explicitly filter by what `SomeSiennaPackage.jl` exports:

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
    hundreds of [missing docstring](@ref miss_doc) errors:

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


### Remove other types of documentation


### Look at the compiled .html!
!!! tip "Do"
    - [Compile](@ref "Compile and View Documentation Locally") the tutorial regularly and
        look at it
    - Check method signatures and argument lists are formatted correctly 
