@testset "Test generated structs" begin
    descriptor_file = joinpath(@__DIR__, "..", "src", "descriptors", "structs.json")
    existing_dir = joinpath(@__DIR__, "..", "src", "generated")
    @test IS.test_generated_structs(descriptor_file, existing_dir)
end

@testset "Test generated struct missing required field" begin
    descriptor_file = joinpath(@__DIR__, "..", "src", "descriptors", "structs.json")
    data = open(descriptor_file, "r") do io
        JSON3.read(io, Dict)
    end
    for item in data["auto_generated_structs"]
        if item["struct_name"] == "DeterministicMetadata"
            found = false
            for (i, field) in enumerate(item["fields"])
                if field["name"] == "name"
                    popat!(item["fields"], i)
                    found = true
                    break
                end
            end
            @assert found
            break
        end
    end

    new_file = joinpath(tempdir(), "structs.json")
    open(new_file, "w") do io
        write(io, JSON3.write(data))
    end
    new_dir = joinpath(tempdir(), "generated")
    @test_throws IS.DataFormatError IS.test_generated_structs(new_file, new_dir)
end
