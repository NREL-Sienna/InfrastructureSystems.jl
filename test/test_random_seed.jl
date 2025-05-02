@testset "Random Seed" begin
    @test isa(Int, IS.get_random_seed())
end

@testset "Random Seed from ENV" begin
    ENV["SIENNA_RANDOM_SEED"] = "12345"
    @test IS.get_random_seed() == 12345
    ENV["SIENNA_RANDOM_SEED"] = "not_a_number"
    @test_throws ErrorException IS.get_random_seed()
end
