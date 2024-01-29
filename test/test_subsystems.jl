function create_system_with_subsystems()
    sys = IS.SystemData(; time_series_in_memory = true)

    components = IS.TestComponent[]
    for i in 1:5
        name = "component_$i"
        component = IS.TestComponent(name, i)
        IS.add_component!(sys, component)
        push!(components, component)
    end

    subsystems = String[]
    for i in 1:3
        name = "subsystem_$i"
        IS.add_subsystem!(sys, name)
        push!(subsystems, name)
    end

    IS.add_component_to_subsystem!(sys, subsystems[1], components[1])
    IS.add_component_to_subsystem!(sys, subsystems[1], components[2])
    IS.add_component_to_subsystem!(sys, subsystems[2], components[2])
    IS.add_component_to_subsystem!(sys, subsystems[2], components[3])
    IS.add_component_to_subsystem!(sys, subsystems[3], components[3])
    IS.add_component_to_subsystem!(sys, subsystems[3], components[4])
    return sys
end

@testset "Test get subsystems and components" begin
    sys = create_system_with_subsystems()
    components = Dict(x.name => x for x in IS.get_components(IS.TestComponent, sys))
    @test sort!(collect(IS.get_subsystems(sys))) ==
          ["subsystem_1", "subsystem_2", "subsystem_3"]
    @test IS.has_component(sys, "subsystem_1", components["component_1"])
    @test IS.has_component(sys, "subsystem_1", components["component_2"])
    @test IS.has_component(sys, "subsystem_2", components["component_2"])
    @test IS.has_component(sys, "subsystem_2", components["component_3"])
    @test IS.has_component(sys, "subsystem_3", components["component_3"])
    @test IS.has_component(sys, "subsystem_3", components["component_4"])
    @test !IS.has_component(sys, "subsystem_3", components["component_5"])
    @test sort!(IS.get_name.(IS.get_subsystem_components(sys, "subsystem_2"))) ==
          ["component_2", "component_3"]
    @test IS.get_participating_subsystems(sys, components["component_1"]) == ["subsystem_1"]
    @test_throws ArgumentError IS.add_subsystem!(sys, "subsystem_1")
end

@testset "Test get_components" begin
    sys = create_system_with_subsystems()
    @test length(
        IS.get_components(IS.TestComponent, sys; subsystem_name = "subsystem_1"),
    ) == 2
    @test collect(
        IS.get_components(
            x -> x.val == 1,
            IS.TestComponent,
            sys;
            subsystem_name = "subsystem_1",
        ),
    )[1].name == "component_1"
end

@testset "Test subsystem after remove_component" begin
    sys = create_system_with_subsystems()
    components = Dict(x.name => x for x in IS.get_components(IS.TestComponent, sys))
    IS.remove_component!(sys, components["component_3"])
    @test !IS.has_component(sys, "subsystem_2", components["component_3"])
    @test !IS.has_component(sys, "subsystem_3", components["component_3"])
    @test IS.has_component(sys, "subsystem_2", components["component_2"])
    @test IS.has_component(sys, "subsystem_3", components["component_4"])
end

@testset "Test removal of subsystem" begin
    sys = create_system_with_subsystems()
    component = IS.get_component(IS.TestComponent, sys, "component_2")
    IS.remove_subsystem!(sys, "subsystem_2")
    @test sort!(collect(IS.get_subsystems(sys))) == ["subsystem_1", "subsystem_3"]
    @test IS.get_participating_subsystems(sys, component) == ["subsystem_1"]
    @test_throws ArgumentError IS.remove_subsystem!(sys, "subsystem_2")
end

@testset "Test removal of subsystem component" begin
    sys = create_system_with_subsystems()
    component = IS.get_component(IS.TestComponent, sys, "component_2")
    IS.remove_subsystem_component!(sys, "subsystem_2", component)
    @test IS.get_name.(IS.get_subsystem_components(sys, "subsystem_2")) == ["component_3"]
    @test_throws ArgumentError IS.remove_subsystem_component!(sys, "subsystem_2", component)
end

@testset "Test addition of component to invalid subsystem" begin
    sys = create_system_with_subsystems()
    component = IS.get_component(IS.TestComponent, sys, "component_1")
    @test_throws ArgumentError IS.add_component_to_subsystem!(sys, "invalid", component)
end

@testset "Test addition of duplicate component to subsystem" begin
    sys = create_system_with_subsystems()
    component = IS.get_component(IS.TestComponent, sys, "component_1")
    @test_throws ArgumentError IS.add_component_to_subsystem!(sys, "subsystem_1", component)
end

@testset "Test addition of non-system component" begin
    sys = create_system_with_subsystems()
    component = IS.TestComponent("new_component", 10)
    @test_throws ArgumentError IS.add_component_to_subsystem!(sys, "subsystem_1", component)
end
