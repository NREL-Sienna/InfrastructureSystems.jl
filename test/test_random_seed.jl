IS = InfrastructureSystems
@testset "Random Seed" begin
    @test isa(IS.get_random_seed(), Int)
end

@testset "Random Seed from ENV" begin
    ENV["SIENNA_RANDOM_SEED"] = "12345"
    @test IS.get_random_seed() == 12345
    ENV["SIENNA_RANDOM_SEED"] = "not_a_number"
    @test_logs (
        :error,
        "SIENNA_RANDOM_SEED: not_a_number can't be read as an integer value",
    ) @test_throws ArgumentError IS.get_random_seed()
    pop!(ENV, "SIENNA_RANDOM_SEED")
end
