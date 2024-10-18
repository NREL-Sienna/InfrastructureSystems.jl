# Explanation

## History and Motivation

During the first phase of Sienna's (previously SIIP's) development, Sienna used a 3-part
documentation organization, based on the expected needs of different user personas:

  - **Modeler**: Users that want to use existing functionality
  - **Model Developer**: Users that want to develop custom structs, components, models, and/or workflows
  - **Code Base Developers**: Users that want to add new core functionalities or fix bugs in the core capabilities

However, as Sienna's user base has expanded, it has become apparent that this previous
organization is no longer serving. As of 2024, a new effort is underway to clean up and
re-organize the Sienna documentation according to the 4-part [Diataxis](https://diataxis.fr/)
framework, a well-established, systematic approach to technical documentation split up into
[Tutorials](https://diataxis.fr/tutorials/),
[How-to guides](https://diataxis.fr/how-to-guides/),
[Reference](https://diataxis.fr/reference/), and
[Explanation](https://diataxis.fr/explanation/).

In addition, the current documentation has multiple quality issues, including misformatted
text, broken reference links, and documentation that has been written but is not visible to
users in the API ("missing docstrings"). While the [style guide](@ref style_guide)
has been available, the guide focuses primarily on the style of code itself, without
providing clear guidelines and best practices for other parts of the documentation besides
docstrings. In addition, the first stage of Sienna's development coincided with the initial
development of the [`Documenter.jl`](https://documenter.juliadocs.org/stable/) package.
Early versions of Sienna's packages were documented requiring `Documenter.jl` v0.27, and in
the meantime, `Documenter.jl` has released its v1.0 and onwards, which contain much
more rigorous checks for documentation quality. Sienna's packages have not kept up with
these improvements. 

We aim to remedy these issues through a concerted clean up and re-organization effort, 
compliance with `Documenter.jl` >v1.0's quality control checks, and clear best practice
guidelines that can be applied as a regular part of future pull request reviews.
