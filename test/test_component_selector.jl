# Tests `src/component_selector.jl`

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

sort_name(x) = sort(collect(x); by = IS.get_name)

@testset "Test helper functions" begin
    @test IS.subtype_to_string(IS.TestComponent) == "TestComponent"
    @test IS.component_to_qualified_string(IS.TestComponent, "Component1") ==
          "TestComponent__Component1"
    @test IS.component_to_qualified_string(IS.TestComponent("Component1", 11)) ==
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
        ) == test_gen_ent

        # Naming
        @test IS.get_name(test_gen_ent) == "TestComponent__Component1"
        @test IS.get_name(named_test_gen_ent) == "CompOne"
        @test IS.default_name(test_gen_ent) == "TestComponent__Component1"

        # Contents
        @test collect(
            IS.get_components(IS.select_components(IS.SimpleTestComponent, ""), test_sys),
        ) == Vector{IS.InfrastructureSystemsComponent}()
        the_components = collect(IS.get_components(test_gen_ent, test_sys))
        @test length(the_components) == 1
        @test typeof(first(the_components)) == IS.TestComponent
        @test IS.get_name(first(the_components)) == "Component1"
    end
end

@testset "Test ListComponentSelector" begin
    @testset for test_sys in [cstest_make_components(), cstest_make_system_data()]
        comp_ent_1 = IS.select_components(IS.TestComponent, "Component1")
        comp_ent_2 = IS.select_components(IS.AdditionalTestComponent, "Component3")
        test_list_ent = IS.ListComponentSelector((comp_ent_1, comp_ent_2), nothing)
        named_test_list_ent = IS.ListComponentSelector((comp_ent_1, comp_ent_2), "TwoComps")

        # Equality
        @test IS.ListComponentSelector((comp_ent_1, comp_ent_2), nothing) == test_list_ent
        @test IS.ListComponentSelector((comp_ent_1, comp_ent_2), "TwoComps") ==
              named_test_list_ent

        # Construction
        @test IS.select_components(comp_ent_1, comp_ent_2;) == test_list_ent
        @test IS.select_components(comp_ent_1, comp_ent_2; name = "TwoComps") ==
              named_test_list_ent

        # Naming
        @test IS.get_name(test_list_ent) ==
              "[TestComponent__Component1, AdditionalTestComponent__Component3]"
        @test IS.get_name(named_test_list_ent) == "TwoComps"

        # Contents
        @test collect(IS.get_components(IS.select_components(), test_sys)) ==
              Vector{IS.InfrastructureSystemsComponent}()
        the_components = collect(IS.get_components(test_list_ent, test_sys))
        @test length(the_components) == 2
        @test IS.get_component(IS.TestComponent, test_sys, "Component1") in the_components
        @test IS.get_component(IS.AdditionalTestComponent, test_sys, "Component3") in
              the_components

        @test collect(IS.get_subselectors(IS.select_components(), test_sys)) ==
              Vector{IS.InfrastructureSystemsComponent}()
        the_subselectors = collect(IS.get_subselectors(test_list_ent, test_sys))
        @test length(the_subselectors) == 2
        @test comp_ent_1 in the_subselectors
        @test comp_ent_2 in the_subselectors
    end
end

@testset "Test SubtypeComponentSelector" begin
    @testset for test_sys in [cstest_make_components(), cstest_make_system_data()]
        test_sub_ent = IS.SubtypeComponentSelector(IS.TestComponent, nothing)
        named_test_sub_ent = IS.SubtypeComponentSelector(IS.TestComponent, "TComps")

        # Equality
        @test IS.SubtypeComponentSelector(IS.TestComponent, nothing) == test_sub_ent
        @test IS.SubtypeComponentSelector(IS.TestComponent, "TComps") == named_test_sub_ent

        # Construction
        @test IS.select_components(IS.TestComponent) == test_sub_ent
        @test IS.select_components(IS.TestComponent; name = "TComps") == named_test_sub_ent

        # Naming
        @test IS.get_name(test_sub_ent) == "TestComponent"
        @test IS.get_name(named_test_sub_ent) == "TComps"
        @test IS.default_name(test_sub_ent) == "TestComponent"

        # Contents
        answer = sort_name(IS.get_components(IS.TestComponent, test_sys))

        @test collect(
            IS.get_components(IS.select_components(IS.SimpleTestComponent), test_sys),
        ) == Vector{IS.InfrastructureSystemsComponent}()
        the_components = sort_name(IS.get_components(test_sub_ent, test_sys))
        @test all(the_components .== answer)

        @test collect(
            IS.get_subselectors(IS.select_components(IS.SimpleTestComponent), test_sys),
        ) == Vector{IS.ComponentSelectorElement}()
        the_subselectors = sort_name(IS.get_subselectors(test_sub_ent, test_sys))
        @test all(the_subselectors .== IS.select_components.(answer))
    end
end

@testset "Test FilterComponentSelector" begin
    @testset for test_sys in [cstest_make_components(), cstest_make_system_data()]
        val_over_ten(x) = IS.get_val(x) > 10
        test_filter_ent =
            IS.FilterComponentSelector(val_over_ten, IS.TestComponent, nothing)
        named_test_filter_ent =
            IS.FilterComponentSelector(val_over_ten, IS.TestComponent, "TCOverTen")

        # Equality
        @test IS.FilterComponentSelector(val_over_ten, IS.TestComponent, nothing) ==
              test_filter_ent
        @test IS.FilterComponentSelector(val_over_ten, IS.TestComponent, "TCOverTen") ==
              named_test_filter_ent

        # Construction
        @test IS.select_components(val_over_ten, IS.TestComponent) == test_filter_ent
        @test IS.select_components(val_over_ten, IS.TestComponent, "TCOverTen") ==
              named_test_filter_ent
        bad_input_fn(x::Integer) = true  # Should always fail to construct
        specific_input_fn(x::IS.AdditionalTestComponent) = true  # Should require compatible subtype
        @test_throws ArgumentError IS.select_components(bad_input_fn, IS.TestComponent)
        @test_throws ArgumentError IS.select_components(
            specific_input_fn,
            IS.InfrastructureSystemsComponent,
        )
        @test_throws ArgumentError IS.select_components(specific_input_fn, IS.TestComponent)
        @test IS.select_components(specific_input_fn, IS.AdditionalTestComponent) isa Any  # test absence of error

        # Naming
        @test IS.get_name(test_filter_ent) == "val_over_ten__TestComponent"
        @test IS.get_name(named_test_filter_ent) == "TCOverTen"

        # Contents
        answer =
            filter(val_over_ten, collect(IS.get_components(IS.TestComponent, test_sys)))

        @test collect(
            IS.get_components(
                IS.select_components(x -> true, IS.SimpleTestComponent),
                test_sys,
            )) == Vector{IS.InfrastructureSystemsComponent}()
        @test collect(
            IS.get_components(
                IS.select_components(x -> false, IS.InfrastructureSystemsComponent),
                test_sys,
            )) == Vector{IS.InfrastructureSystemsComponent}()
        @test all(collect(IS.get_components(test_filter_ent, test_sys)) .== answer)

        @test collect(
            IS.get_subselectors(
                IS.select_components(x -> true, IS.SimpleTestComponent),
                test_sys,
            )) == Vector{IS.ComponentSelectorElement}()
        @test collect(
            IS.get_subselectors(
                IS.select_components(x -> false, IS.InfrastructureSystemsComponent),
                test_sys,
            )) == Vector{IS.ComponentSelectorElement}()
        @test all(
            collect(IS.get_subselectors(test_filter_ent, test_sys)) .==
            IS.select_components.(answer),
        )
    end
end
