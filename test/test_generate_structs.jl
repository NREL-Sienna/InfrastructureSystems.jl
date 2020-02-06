@testset "Test generated structs" begin
    descriptor_file = joinpath(@__DIR__, "..", "src", "descriptors", "structs.json")
    existing_dir = joinpath(@__DIR__, "..", "src", "generated")
    @test IS.test_generated_structs(descriptor_file, existing_dir)
end
