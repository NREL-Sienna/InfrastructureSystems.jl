main_paths = ["./src", "./test"]
for main_path in main_paths
    for folder in readdir(main_path)
        folder == "generated" && continue
        @show folder_path = joinpath(main_path, folder)
        try format(folder_path;
            whitespace_ops_in_indices = true,
            remove_extra_newlines = true,
            verbose = true
            )
        catch
            @warn("Formatter Failed at file $(folder_path)")
        end
    end
end
