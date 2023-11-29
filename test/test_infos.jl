@testset "Test add_info" begin
    container = IS.Infos(IS.InMemoryTimeSeriesStorage())
    geo_info = IS.InfrastructureSystemsGeo()
    component = IS.TestComponent("component1", 5)
    IS.add_info!(container, geo_info, component)
    @test length(container.data) == 1
    @test length(container.data[IS.InfrastructureSystemsGeo]) == 1
    @test IS.get_num_infos(container) == 1
    @test_throws ArgumentError IS.add_info!(container, geo_info, component)

    container = IS.Infos(IS.InMemoryTimeSeriesStorage())
    geo_info = IS.InfrastructureSystemsGeo()
    @test_throws ArgumentError IS._add_info!(container, geo_info)
end

@testset "Test clear_infos" begin
    container = IS.Infos(IS.InMemoryTimeSeriesStorage())
    geo_info = IS.InfrastructureSystemsGeo()
    component = IS.TestComponent("component1", 5)
    IS.add_info!(container, geo_info, component)
    @test IS.get_num_infos(container) == 1

    IS.clear_infos!(component)
    @test isempty(IS.get_components_uuid(geo_info))
    IS.clear_infos!(container)
    infos = IS.get_infos(IS.InfrastructureSystemsGeo, container)
    @test length(infos) == 0
end

@testset "Test remove_info" begin
    container = IS.Infos(IS.InMemoryTimeSeriesStorage())
    geo_info = IS.InfrastructureSystemsGeo()
    component = IS.TestComponent("component1", 5)
    IS.add_info!(container, geo_info, component)
    @test IS.get_num_infos(container) == 1

    IS.remove_info!(component, geo_info)
    @test isempty(IS.get_infos_container(component))
    @test isempty(IS.get_components_uuid(geo_info))
end

@testset "Test iterate_Infos" begin
    container = IS.Infos(IS.InMemoryTimeSeriesStorage())
    geo_info = IS.InfrastructureSystemsGeo()
    component = IS.TestComponent("component1", 5)
    IS.add_info!(container, geo_info, component)

    i = 0
    for component in IS.iterate_infos(container)
        i += 1
    end
    @test i == 1
end

@testset "Summarize Infos" begin
    container = IS.Infos(IS.InMemoryTimeSeriesStorage())
    geo_info = IS.InfrastructureSystemsGeo()
    component = IS.TestComponent("component1", 5)
    IS.add_info!(container, geo_info, component)
    summary(devnull, container)
end

@testset "Test infos serialization" begin
    container = IS.Infos(IS.InMemoryTimeSeriesStorage())
    geo_info = IS.InfrastructureSystemsGeo()
    component = IS.TestComponent("component1", 5)
    IS.add_info!(container, geo_info, component)
    data = IS.serialize(container)
    @test data isa Vector
    @test !isempty(data)
    @test data[1] isa Dict
end
