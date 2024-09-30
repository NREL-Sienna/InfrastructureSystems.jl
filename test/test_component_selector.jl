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

sort_name!(x) = sort!(collect(x); by = IS.get_name)

@testset "Test helper functions" begin
    @test IS.subtype_to_string(IS.TestComponent) == "TestComponent"
    @test IS.component_to_qualified_string(IS.TestComponent, "Component1") ==
          "TestComponent__Component1"
    @test IS.component_to_qualified_string(IS.TestComponent("Component1", 11)) ==
          "TestComponent__Component1"

    @test IS.validate_groupby(:all) == :all
    @test IS.validate_groupby(:each) == :each
    @test_throws ArgumentError IS.validate_groupby(:other)
    @test IS.validate_groupby(string) == string
end

@testset "Test NameComponentSelector" begin
    # Everything should work for both Components and SystemData
    @testset for test_sys in [cstest_make_components(), cstest_make_system_data()]
        test_gen_ent = IS.NameComponentSelector(IS.TestComponent, "Component1", nothing)
        named_test_gen_ent =
            IS.NameComponentSelector(IS.TestComponent, "Component1", "CompOne")

        # Equality
        @test IS.NameComponentSelector(IS.TestComponent, "Component1", nothing) ==
              test_gen_ent
        @test IS.NameComponentSelector(IS.TestComponent, "Component1", "CompOne") ==
              named_test_gen_ent

        # Construction
        @test IS.make_selector(IS.TestComponent, "Component1") == test_gen_ent
        @test IS.make_selector(IS.TestComponent, "Component1"; name = "CompOne") ==
              named_test_gen_ent
        @test IS.make_selector(
            IS.get_component(IS.TestComponent, test_sys, "Component1"),
        ) == test_gen_ent

        # Naming
        @test IS.get_name(test_gen_ent) == "TestComponent__Component1"
        @test IS.get_name(named_test_gen_ent) == "CompOne"
        @test IS.default_name(test_gen_ent) == "TestComponent__Component1"

        # Contents
        @test collect(
            IS.get_components(IS.make_selector(IS.SimpleTestComponent, ""), test_sys),
        ) == Vector{IS.InfrastructureSystemsComponent}()
        the_components = collect(IS.get_components(test_gen_ent, test_sys))
        @test length(the_components) == 1
        @test typeof(first(the_components)) == IS.TestComponent
        @test IS.get_name(first(the_components)) == "Component1"
        @test Set(
            collect(IS.get_components(test_gen_ent, test_sys; filterby = x -> true)),
        ) == Set(the_components)
        @test length(
            collect(IS.get_components(test_gen_ent, test_sys; filterby = x -> false)),
        ) == 0
        @test IS.get_component(test_gen_ent, test_sys; filterby = x -> true) ==
              first(the_components)
        @test isnothing(IS.get_component(test_gen_ent, test_sys; filterby = x -> false))

        @test only(IS.get_groups(test_gen_ent, test_sys)) == test_gen_ent
    end
end

@testset "Test ListComponentSelector" begin
    @testset for test_sys in [cstest_make_components(), cstest_make_system_data()]
        comp_ent_1 = IS.make_selector(IS.TestComponent, "Component1")
        comp_ent_2 = IS.make_selector(IS.AdditionalTestComponent, "Component3")
        test_list_ent = IS.ListComponentSelector((comp_ent_1, comp_ent_2), nothing)
        named_test_list_ent = IS.ListComponentSelector((comp_ent_1, comp_ent_2), "TwoComps")

        # Equality
        @test IS.ListComponentSelector((comp_ent_1, comp_ent_2), nothing) == test_list_ent
        @test IS.ListComponentSelector((comp_ent_1, comp_ent_2), "TwoComps") ==
              named_test_list_ent

        # Construction
        @test IS.make_selector(comp_ent_1, comp_ent_2;) == test_list_ent
        @test IS.make_selector(comp_ent_1, comp_ent_2; name = "TwoComps") ==
              named_test_list_ent

        # Naming
        @test IS.get_name(test_list_ent) ==
              "[TestComponent__Component1, AdditionalTestComponent__Component3]"
        @test IS.get_name(named_test_list_ent) == "TwoComps"

        # Contents
        @test collect(IS.get_components(IS.make_selector(), test_sys)) ==
              Vector{IS.InfrastructureSystemsComponent}()
        the_components = collect(IS.get_components(test_list_ent, test_sys))
        @test length(the_components) == 2
        @test IS.get_component(IS.TestComponent, test_sys, "Component1") in the_components
        @test IS.get_component(IS.AdditionalTestComponent, test_sys, "Component3") in
              the_components
        @test Set(
            collect(IS.get_components(test_list_ent, test_sys; filterby = x -> true)),
        ) == Set(the_components)
        @test length(
            collect(IS.get_components(test_list_ent, test_sys; filterby = x -> false)),
        ) == 0

        @test collect(IS.get_groups(IS.make_selector(), test_sys)) ==
              Vector{IS.InfrastructureSystemsComponent}()
        the_groups = collect(IS.get_groups(test_list_ent, test_sys))
        @test length(the_groups) == 2
        @test comp_ent_1 in the_groups
        @test comp_ent_2 in the_groups
        @test Set(
            collect(IS.get_groups(test_list_ent, test_sys; filterby = x -> true)),
        ) == Set(the_groups)
        # Even if we eventually filter out all the components, ListComponentSelector says we must have exactly the groups specified
        @test length(
            collect(IS.get_groups(test_list_ent, test_sys; filterby = x -> false)),
        ) == 2
    end
end

@testset "Test TypeComponentSelector" begin
    @testset for test_sys in [cstest_make_components(), cstest_make_system_data()]
        test_sub_ent = IS.TypeComponentSelector(IS.TestComponent, nothing, :all)
        named_test_sub_ent = IS.TypeComponentSelector(IS.TestComponent, "TComps", :all)

        # Equality
        @test IS.TypeComponentSelector(IS.TestComponent, nothing, :all) == test_sub_ent
        @test IS.TypeComponentSelector(IS.TestComponent, "TComps", :all) ==
              named_test_sub_ent

        # Construction
        @test IS.make_selector(IS.TestComponent) == test_sub_ent
        @test IS.make_selector(IS.TestComponent; name = "TComps") == named_test_sub_ent
        @test IS.make_selector(IS.TestComponent; groupby = string) isa
              IS.TypeComponentSelector

        # Naming
        @test IS.get_name(test_sub_ent) == "TestComponent"
        @test IS.get_name(named_test_sub_ent) == "TComps"
        @test IS.default_name(test_sub_ent) == "TestComponent"

        # Contents
        answer = sort_name!(IS.get_components(IS.TestComponent, test_sys))

        @test collect(
            IS.get_components(IS.make_selector(IS.SimpleTestComponent), test_sys),
        ) == Vector{IS.InfrastructureSystemsComponent}()
        the_components = IS.get_components(test_sub_ent, test_sys)
        @test all(sort_name!(the_components) .== answer)
        @test Set(
            collect(IS.get_components(test_sub_ent, test_sys; filterby = x -> true)),
        ) == Set(the_components)
        @test length(
            collect(IS.get_components(test_sub_ent, test_sys; filterby = x -> false)),
        ) == 0

        # Grouping inherits from `DynamicallyGroupedComponentSelector` and is tested elsewhere
    end
end

@testset "Test FilterComponentSelector" begin
    @testset for test_sys in [cstest_make_components(), cstest_make_system_data()]
        val_over_ten(x) = IS.get_val(x) > 10
        test_filter_ent =
            IS.FilterComponentSelector(IS.TestComponent, val_over_ten, nothing, :all)
        named_test_filter_ent =
            IS.FilterComponentSelector(IS.TestComponent, val_over_ten, "TCOverTen", :all)

        # Equality
        @test IS.FilterComponentSelector(IS.TestComponent, val_over_ten, nothing, :all) ==
              test_filter_ent
        @test IS.FilterComponentSelector(
            IS.TestComponent,
            val_over_ten,
            "TCOverTen",
            :all,
        ) == named_test_filter_ent

        # Construction
        @test IS.make_selector(IS.TestComponent, val_over_ten) == test_filter_ent
        @test IS.make_selector(val_over_ten, IS.TestComponent) == test_filter_ent
        @test IS.make_selector(IS.TestComponent, val_over_ten; name = "TCOverTen") ==
              named_test_filter_ent
        @test IS.make_selector(IS.TestComponent, val_over_ten; groupby = string) isa
              IS.FilterComponentSelector

        # Naming
        @test IS.get_name(test_filter_ent) == "val_over_ten__TestComponent"
        @test IS.get_name(named_test_filter_ent) == "TCOverTen"

        # Contents
        answer =
            sort_name!(
                filter(
                    val_over_ten,
                    collect(IS.get_components(IS.TestComponent, test_sys)),
                ),
            )

        @test collect(
            IS.get_components(
                IS.make_selector(IS.SimpleTestComponent, x -> true),
                test_sys,
            )) == Vector{IS.InfrastructureSystemsComponent}()
        @test collect(
            IS.get_components(
                IS.make_selector(IS.InfrastructureSystemsComponent, x -> false),
                test_sys,
            )) == Vector{IS.InfrastructureSystemsComponent}()
        the_components = IS.get_components(test_filter_ent, test_sys)
        @test all(sort_name!(the_components) .== answer)
        @test Set(IS.get_components(test_filter_ent, test_sys; filterby = x -> true)) ==
              Set(the_components)
        @test length(
            collect(IS.get_components(test_filter_ent, test_sys; filterby = x -> false)),
        ) == 0
    end
end

@testset "Test DynamicallyGroupedComponentSelector grouping" begin
    # We'll use TypeComponentSelector as the token example
    @assert IS.TypeComponentSelector <: IS.DynamicallyGroupedComponentSelector

    all_selector = IS.make_selector(IS.TestComponent; groupby = :all)
    each_selector = IS.make_selector(IS.TestComponent; groupby = :each)
    @test IS.make_selector(IS.TestComponent; groupby = :all) == all_selector
    @test_throws ArgumentError IS.make_selector(IS.TestComponent; groupby = :other)
    partition_selector = IS.make_selector(IS.TestComponent;
        groupby = x -> length(IS.get_name(x)))

    for test_sys in [cstest_make_components(), cstest_make_system_data()]
        @test only(IS.get_groups(all_selector, test_sys)) == all_selector
        @test Set(IS.get_name.(IS.get_groups(each_selector, test_sys))) ==
              Set(
            IS.component_to_qualified_string.(Ref(IS.TestComponent),
                IS.get_name.(IS.get_components(each_selector, test_sys))),
        )
        @test length(
            collect(
                IS.get_groups(each_selector, test_sys;
                    filterby = x -> length(IS.get_name(x)) < 11),
            ),
        ) == 2
        @test Set(IS.get_name.(IS.get_groups(partition_selector, test_sys))) ==
              Set(["13", "10"])
        @test length(
            collect(
                IS.get_groups(partition_selector, test_sys;
                    filterby = x -> length(IS.get_name(x)) < 11),
            ),
        ) == 1
    end
end

@testset "Test alternative interfaces" begin
    test_sys = cstest_make_components()
    selector = IS.make_selector(IS.TestComponent, "Component1")
    @test IS.get_components(selector, test_sys; filterby = x -> true) ==
          IS.get_components(x -> true, selector, test_sys)
    @test IS.get_component(selector, test_sys; filterby = x -> true) ==
          IS.get_component(x -> true, selector, test_sys)
    @test IS.get_groups(selector, test_sys; filterby = x -> true) ==
          IS.get_groups(x -> true, selector, test_sys)
end
