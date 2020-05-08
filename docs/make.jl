using Documenter, InfrastructureSystems

if haskey(ENV, "GITHUB_ACTIONS")
    ENV["JULIA_DEBUG"] = "Documenter"
end

makedocs(
    modules = [InfrastructureSystems],
    format = Documenter.HTML(prettyurls = haskey(ENV, "GITHUB_ACTIONS"),),
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
