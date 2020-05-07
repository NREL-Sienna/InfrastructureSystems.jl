using Documenter, InfrastructureSystems

makedocs(
    modules = [InfrastructureSystems],
    format = Documenter.HTML(),
    sitename = "InfrastructureSystems.jl",
    pages = Any[ # Compat: `Any` for 0.4 compat
        "Home" => "index.md",
        "User Guide" => "man/guide.md",
        "API" => Any[
            "InfrastructureSystems" => "api/InfrastructureSystems.md"
        ]
    ]
)

deploydocs(
    repo = "github.com/NREL-SIIP/InfrastructureSystems.jl.git",
    target = "build",
    branch = "gh-pages",
    devbranch = "master",
    devurl = "dev",
    versions = ["stable" => "v^", "v#.#"],
    push_preview = true,
)
