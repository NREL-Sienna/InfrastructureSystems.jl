@testset "Test add_info" begin
    container = IS.Infos(IS.InMemoryTimeSeriesStorage())
    geo_info = IS.InfrastructureSystemsGeo()
    IS.add_info!(container, geo_info)
    @test length(container.data) == 1
    @test length(container.data[IS.InfrastructureSystemsGeo]) == 1
    @test IS.get_num_infos(container) == 1

    component = IS.TestComponent("component1", 5)
    IS.add_info!(container, geo_info, component)

    @test_throws ArgumentError IS.add_component!(container, component)

    struct BadComponent
        name::AbstractString
        val::Int
    end

    container = IS.Components(IS.InMemoryTimeSeriesStorage())
    component = BadComponent("component1", 5)
    @test_throws MethodError IS.add_component!(container, component)
end
