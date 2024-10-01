using Pkg
Pkg.activate(@__DIR__)
Pkg.instantiate()
Pkg.update()

using JuliaFormatter

main_paths = ["./src", "./test", "./docs/src"]
for main_path in main_paths
    for (root, dir, files) in walkdir(main_path)
        for f in files
        @show file_path = abspath(root, f)
        !((occursin(".jl", f) || occursin(".md", f))) && continue
        format(file_path;
            whitespace_ops_in_indices = true,
            remove_extra_newlines = true,
            verbose = true,
            always_for_in = true,
            whitespace_typedefs = true,
            conditional_to_if = true,
            join_lines_based_on_source = true,
            separate_kwargs_with_semicolon = true,
            format_markdown = true,
            # Brackets in code blocks cause formatter to fail, ignore for now
            ignore = ["style.md", "index.md", "tests.md"],

            # always_use_return = true. # Disabled since it throws a lot of false positives
            )
        end
    end
end
