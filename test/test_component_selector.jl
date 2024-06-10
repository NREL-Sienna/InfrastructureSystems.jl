# TODO now: add some ComponentSelector tests
# TODO later: make comprehensive

cstest_get_test_components() = [
    IS.TestComponent("DuplicateName", 10),
    IS.TestComponent("Component1", 11),
    IS.TestComponent("Component2", 12),
    IS.AdditionalTestComponent("DuplicateName", 20),
    IS.AdditionalTestComponent("Component3", 23),
    IS.AdditionalTestComponent("Component4", 24),
]

function cstest_make_components()
    container = IS.Components(IS.TimeSeriesManager(; in_memory = true))
    IS.add_component!.(Ref(container), cstest_get_test_components())
    return container
end

function cstest_make_system_data()
    data = IS.SystemData()
    IS.add_component!.(Ref(data), cstest_get_test_components())
    return data
end

@testset "Test helper functions" begin
    @test IS.subtype_to_string(IS.TestComponent) == "TestComponent"
    @test IS.component_to_qualified_string(IS.TestComponent, "Component1") ==
          "TestComponent__Component1"
end

@testset "Test SingleComponentSelector" begin
    # Everything should work for both Components and SystemData
    @testset for test_sys in [cstest_make_components(), cstest_make_system_data()]
        test_gen_ent = IS.SingleComponentSelector(IS.TestComponent, "Component1", nothing)
        named_test_gen_ent =
            IS.SingleComponentSelector(IS.TestComponent, "Component1", "CompOne")

        # Equality
        @test IS.SingleComponentSelector(IS.TestComponent, "Component1", nothing) ==
              test_gen_ent
        @test IS.SingleComponentSelector(IS.TestComponent, "Component1", "CompOne") ==
              named_test_gen_ent

        # Construction
        @test IS.select_components(IS.TestComponent, "Component1") == test_gen_ent
        @test IS.select_components(IS.TestComponent, "Component1", "CompOne") ==
              named_test_gen_ent
        @test IS.select_components(
            IS.get_component(IS.TestComponent, test_sys, "Component1"),
        ) ==
              test_gen_ent

        # Naming
        @test IS.get_name(test_gen_ent) == "TestComponent__Component1"
        @test IS.get_name(named_test_gen_ent) == "CompOne"
        @test IS.default_name(test_gen_ent) == "TestComponent__Component1"

        # Contents
        @test collect(
            IS.get_components(IS.select_components(IS.SimpleTestComponent, ""), test_sys),
        ) ==
              Vector{IS.InfrastructureSystemsComponent}()
        the_components = collect(IS.get_components(test_gen_ent, test_sys))
        @test length(the_components) == 1
        @test typeof(first(the_components)) == IS.TestComponent
        @test IS.get_name(first(the_components)) == "Component1"
    end
end
