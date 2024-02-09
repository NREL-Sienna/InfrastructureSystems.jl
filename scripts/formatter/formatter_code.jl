using Pkg
Pkg.activate(@__DIR__)
Pkg.instantiate()
Pkg.update()

using JuliaFormatter

main_paths = ["."]
for main_path in main_paths
    for (root, dir, files) in walkdir(main_path)
        for f in files
            @show file_path = abspath(root, f)
            !occursin(".jl", f) && continue
            format(file_path;
                whitespace_ops_in_indices = true,
                remove_extra_newlines = true,
                verbose = true,
                always_for_in = true,
                whitespace_typedefs = true,
                conditional_to_if = true,
                join_lines_based_on_source = true,
                separate_kwargs_with_semicolon = true,

                # always_use_return = true. # Disabled since it throws a lot of false positives
            )
        end
    end
end

main_paths = ["./docs"]
for main_path in main_paths
    for folder in readdir(main_path)
        @show folder_path = joinpath(main_path, folder)
        if isfile(folder_path)
            !occursin(".md", folder_path) && continue
        end
        format(folder_path;
            format_markdown=true,
            whitespace_ops_in_indices = true,
            remove_extra_newlines = true,
            verbose = true,
            always_for_in = true,
            whitespace_typedefs = true,
            whitespace_in_kwargs = false,
            # always_use_return = true # removed since it has false positives.
            )
    end
end
