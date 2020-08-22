
@testset "Test utility functions" begin
    concrete_types = IS.get_all_concrete_subtypes(IS.InfrastructureSystemsComponent)
    @test length([x for x in concrete_types if isconcretetype(x)]) == length(concrete_types)
end

@testset "Test strip_module_name" begin
    @test IS.strip_module_name("PowerSystems.HydroDispatch") == "HydroDispatch"

    @test IS.strip_module_name("InfrastructureSystems.Deterministic{PowerSystems.HydroDispatch}") ==
          "Deterministic{PowerSystems.HydroDispatch}"

    @test IS.strip_module_name("Deterministic{PowerSystems.HydroDispatch}") ==
          "Deterministic{PowerSystems.HydroDispatch}"
end

@testset "Test strip_parametric_type" begin
    @test IS.strip_parametric_type("Deterministic{PowerSystems.HydroDispatch}") ==
          "Deterministic"

    @test IS.strip_parametric_type("InfrastructureSystems.Deterministic{PowerSystems.HydroDispatch}") ==
          "InfrastructureSystems.Deterministic"
end

@testset "Test serialization utility functions" begin
    struct Foo{Float64, Int} end
    text = "Foo{Float64,Int64}"
    symbol = IS.parse_serialized_type(text)
    @test eval(symbol) == Foo{Float64, Int64}

    text = "Float64"
    symbol = IS.parse_serialized_type(text)
    @test eval(symbol) == Float64

    @test_throws ErrorException IS.parse_serialized_type("foo()")
end

@testset "Test checking of parametric expression characters" begin
    illegal_chars = (
        '+',
        '=',
        '!',
        '@',
        '#',
        '$',
        '%',
        '^',
        '&',
        '*',
        '(',
        ')',
        '-',
        '\\',
        '"',
        ''',
        '\'',
        '[',
        ']',
        '|',
        '~',
        '<',
        '>',
        ';',
        ':',
    )
    for char in illegal_chars
        text = "foo" * char
        @test_throws ErrorException IS._check_expression_characters(text)
    end
end

@testset "Test checking of parametric expressions" begin
    IS._check_parametric_expression(Meta.parse("Foo{Float64,Int64}"))
    @test_throws ErrorException IS._check_parametric_expression(Meta.parse("foo()"))
    expr = Meta.parse("Foo{Float64, print(\"hello\")}")
    @test_throws ErrorException IS._check_parametric_expression(expr)
end

@testset "Test exported names" begin
    @test IS.validate_exported_names(IS)
end

IS.@scoped_enum Fruit begin
    APPLE
    ORANGE
end

@testset "Test scoped_enum" begin
    @test Fruits.APPLE isa Fruits.Fruit
    @test Fruits.ORANGE isa Fruits.Fruit
end

@testset "Test undef component prints" begin
    v = Vector{IS.InfrastructureSystemsComponent}(undef, 3)
    @test sprint(show, v) ==
          "InfrastructureSystems.InfrastructureSystemsComponent[#undef, #undef, #undef]"
end
