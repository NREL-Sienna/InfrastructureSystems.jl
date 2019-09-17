
@testset "Test utility functions" begin
    concrete_types = IS.get_all_concrete_subtypes(IS.InfrastructureSystemsType)
    @test length([x for x in concrete_types if isconcretetype(x)]) == length(concrete_types)
end
