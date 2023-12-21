@testset "Test add_component Deprecation" begin
    data = IS.SystemData()

    component = IS.TestComponent("component1", 5)
    @test_deprecated IS.add_component!(data, component; deserialization_in_progress = true)
end
