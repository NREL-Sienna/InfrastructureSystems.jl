# Write a Tutorial

Tutorials are learning experiences to give our users confidence and experience in using
Sienna.

## Prepare

- If you have not read [Diataxis](https://diataxis.fr/), first read it in its entirety.
- If you have read it, skim the pages on [Tutorials](https://diataxis.fr/tutorials/) and
    the [difference between a tutorial and how-to guide](https://diataxis.fr/tutorials-how-to/)
    to refresh your memory and refer back throughout the process. 
- Look at an example: `PowerSystems.jl`'s
    [Working with Time Series](https://nrel-sienna.github.io/PowerSystems.jl/stable/tutorials/working_with_time_series/)


## Follow the Do's and Don't's

The [Diataxis Tutorials](https://diataxis.fr/tutorials/) page should be your main reference
as you write, but in addition, use these functional and aesthetic guidelines to
ensure we follow Diataxis and avoid common pitfalls from previous versions of Sienna
documentation:

```@contents
Pages = ["write_a_tutorial.md"]
Depth = 3:3
```

### Give it a story

The tutorial should have a logical flow, rather than be a series of disconnected code
demonstrations.
!!! tip "Do"
    Use either named
    [`@example`](https://documenter.juliadocs.org/stable/man/syntax/#reference-at-example)
    or named
    [`@repl`](https://documenter.juliadocs.org/stable/man/syntax/#@repl-block) blocks to
    ensure all code compiles in order in the same environment and ensuring each step builds
    on the previous steps in your story:
    ````markdown
    ```@example my_tutorial
    <Some code here>
    ```
    ````
!!! warning "Don't"
    Use a series of `julia` markdown blocks. These won't be compiled, failing the
        intention of a tutorial and introducing high likelihood of errors as syntax changes.
    ````markdown
    ```julia
    <Some code here>
    ```
    ````

### Make it reproducible
A user should be able to copy and paste every code block in the tutorial in order and get
the exact results seen on the documentation page. 
!!! tip "Do"
    Display all code, starting from `using SomeSiennaPackage` 
!!! warning "Don't"    
    Use `#hide` or
    [`@setup`](https://documenter.juliadocs.org/stable/man/syntax/#reference-at-setup)
    blocks.

### Make it effortless to read
!!! tip "Do"
    Split code examples into ideally 1 (to 3) lines ONLY, with a short preface
    to explain what each line is doing, even if it's obvious to you.
!!! warning "Don't" 
    Use blocks of example code and/or return statements that go over 1 screen
    length in the compiled .html. They are very hard to follow and allow a user to tune out
    or give up.

### Make it realistic and relatable
!!! tip "Do"
    Take the time to define some realistic example data. 
!!! warning "Don't"   
    Use `zero()` or `one()` for all example data.

### Only show relevant log and return statements
!!! tip "Do"
    [Configure the logger](@ref log) or load/build a `System` that returns very
        few log statements. Use semi-colons at line ends to hide return statements if need be.
!!! warning "Don't" 
    Show extensive or confusing log or return statements that bog down a reader with
    information that isn't directly relevant to what you're trying to teach.

### Remove other types of documentation
Particularly when editting existing material, watch out for material that should be
moved elsewhere according to Diataxis principles, especially details and examples
that should live in the docstrings.
!!! tip "Do"
    Preface each call to a new function with a hyperlink to that function's
        docstring so the user can find more detail
!!! warning "Don't"
    Include details about different keyword argument functions or versions of
        a function in the tutorial itself. Some repetition is OK, but details and examples
        live in the docstrings. 

### Look at the compiled .html!
!!! tip "Do"
    - [Compile](@ref "Compile and View Documentation Locally") the tutorial regularly and
        look at it
    - Check all code examples gave the expected results without erroring
    - Check for length of the code examples and iteratively adjust to make it easy
        to read
