using Documenter, InfrastrucutreSystems

makedocs(
    modules = [InfrastrucutreSystems],
    format = Documenter.HTML(),
    sitename = "InfrastrucutreSystems.jl",
    pages = Any[ # Compat: `Any` for 0.4 compat
        "Home" => "index.md",
        # "User Guide" => "man/guide.md",
        "API" => Any[
            "InfrastrucutreSystems" => "api/InfrastrucutreSystems.md"
        ]
    ]
)

deploydocs(
    repo = "github.com/NREL/InfrastrucutreSystems.jl.git",
    branch = "gh-pages",
    target = "build",
    deps = Deps.pip("pygments", "mkdocs", "python-markdown-math"),
    make = nothing,
)
