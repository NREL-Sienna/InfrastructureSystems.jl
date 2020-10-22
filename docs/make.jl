using Documenter, InfrastructureSystems
import DataStructures: OrderedDict
using Literate

if haskey(ENV, "GITHUB_ACTIONS")
    ENV["JULIA_DEBUG"] = "Documenter"
end

pages = OrderedDict(
        "Welcome Page" => "index.md",
        "User Guide" => Any[
            "dev_tools/components_and_container.md",
            "dev_tools/auto_generation.md",
            "dev_tools/time_series.md",
            "dev_tools/recorder.md",
            "dev_tools/tests.md",
            "dev_tools/logging.md",
        ],
        "Style Guide" => "style.md",
        "API" => "InfrastructureSystems.md"
)

# This code performs the automated addition of Literate - Generated Markdowns. The desired
# section name should be the name of the file for instance network_matrices.jl -> Network Matrices
julia_file_filter = x -> occursin(".jl", x)
folders = Dict(
    "Developer Tools" => filter(julia_file_filter, readdir("docs/src/dev_tools")),
)

for (section, folder) in folders
    for file in folder
        section_folder_name = lowercase(replace(section, " " => "_"))
        outputdir = joinpath(pwd(), "docs", "src", "$section_folder_name")
        inputfile = joinpath("$section_folder_name", "$file")
        outputfile = string("generated_", replace("$file", ".jl" => ""))
        Literate.markdown(joinpath(pwd(), "docs", "src", inputfile),
                          outputdir;
                          name = outputfile,
                          credit = false,
                          execute=true)
        subsection = titlecase(replace(split(file, ".")[1], "_" => " "))
        push!(pages[section], ("$subsection" =>  joinpath("$section_folder_name", "$(outputfile).md")))
    end
end

makedocs(
    modules = [InfrastructureSystems],
    format = Documenter.HTML(prettyurls = haskey(ENV, "GITHUB_ACTIONS"),),
    sitename = "InfrastructureSystems.jl",
    pages = Any[p for p in pages]
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
