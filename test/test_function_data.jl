get_test_function_data() = [
    IS.LinearFunctionData(5, 1),
    IS.QuadraticFunctionData(2, 3, 4),
    IS.PiecewiseLinearData([(1, 1), (3, 5), (5, 10)]),
    IS.PiecewiseStepData([1, 3, 5], [2, 2.5]),
]

# Dictionary by type and whether we want NaNs
get_more_test_function_data() = Dict(
    (IS.LinearFunctionData, false) => IS.LinearFunctionData(1.0, 2.0),
    (IS.LinearFunctionData, true) => IS.LinearFunctionData(1.0, NaN),
    (IS.QuadraticFunctionData, false) => IS.QuadraticFunctionData(2.0, 3.0, 4.0),
    (IS.QuadraticFunctionData, true) => IS.QuadraticFunctionData(2.0, 3.0, NaN),
    (IS.PiecewiseLinearData, false) =>
        IS.PiecewiseLinearData([(1.0, 1.0), (3.0, 5.0), (5.0, 10.0)]),
    (IS.PiecewiseLinearData, true) =>
        IS.PiecewiseLinearData([(NaN, 1.0), (3.0, 5.0), (5.0, 10.0)]),
    (IS.PiecewiseStepData, false) =>
        IS.PiecewiseStepData([1.0, 3.0, 5.0], [2.0, 2.5]),
    (IS.PiecewiseStepData, true) =>
        IS.PiecewiseStepData([NaN, 3.0, 5.0], [2.0, 2.5]),
)

@testset "Test FunctionData constructors" begin
    @test all(isa.(get_test_function_data(), IS.FunctionData))
    @test IS.LinearFunctionData(5) isa IS.FunctionData
end

@testset "Test FunctionData validation" begin
    # x-coordinates need to be sorted
    @test_throws ArgumentError IS.PiecewiseLinearData([(2, 1), (1, 1)])
    @test_throws ArgumentError IS.PiecewiseStepData([2, 1], [1])

    # must specify at least two x-coordinates
    @test_throws ArgumentError IS.PiecewiseLinearData([(2, 1)])

    @test IS.PiecewiseLinearData([(x = 1, y = 1), (x = 2, y = 2)]) isa Any  # Test absence of error
    @test IS.PiecewiseLinearData([Dict("x" => 1, "y" => 1), Dict("x" => 2, "y" => 2)]) isa
          Any
    @test_throws ArgumentError IS.PiecewiseLinearData([(y = 1, x = 1), (y = 2, x = 2)])
    @test_throws ArgumentError IS.PiecewiseLinearData([Dict("x" => 1), Dict("x" => 2)])
end

@testset "Test FunctionData trivial getters" begin
    ld = IS.LinearFunctionData(5, 1)
    @test IS.get_proportional_term(ld) == 5

    qd = IS.QuadraticFunctionData(2, 3, 4)
    @test IS.get_quadratic_term(qd) == 2
    @test IS.get_proportional_term(qd) == 3
    @test IS.get_constant_term(qd) == 4

    yd = IS.PiecewiseLinearData([(1, 1), (3, 5)])
    @test IS.get_points(yd) == [(x = 1, y = 1), (x = 3, y = 5)]
    @test IS.get_x_coords(yd) == ([1, 3])
    @test IS.get_y_coords(yd) == ([1, 5])

    dd = IS.PiecewiseStepData([1, 3, 5], [3, 6])
    @test IS.get_x_coords(dd) == [1, 3, 5]
    @test IS.get_y_coords(dd) == [3, 6]
end

@testset "Test FunctionData calculations" begin
    @test length(IS.PiecewiseLinearData([(0, 0), (1, 1), (1.1, 2)])) == 2
    @test length(IS.PiecewiseStepData([1, 1.1, 1.2], [1.1, 10])) == 2

    @test IS.PiecewiseLinearData([(0, 0), (1, 1), (1.1, 2)])[2] == (x = 1, y = 1)
    @test IS.get_x_coords(IS.PiecewiseLinearData([(0, 0), (1, 1), (1.1, 2)])) ==
          [0, 1, 1.1]

    # Tests our overridden Base.:(==)
    @test all(get_test_function_data() .== get_test_function_data())

    @test all(
        isapprox.(
            IS.get_slopes(IS.PiecewiseLinearData([(0, 0), (10, 31.4)])), [3.14]),
    )
    @test isapprox(
        IS.get_slopes(IS.PiecewiseLinearData([(0, 0), (1, 1), (1.1, 2), (1.2, 3)])),
        [1, 10, 10])
    @test isapprox(
        IS.get_slopes(IS.PiecewiseLinearData([(0, 0), (1, 1), (1.1, 2)])),
        [1, 10])

    @test IS.running_sum(IS.PiecewiseStepData([1, 3, 5], [2.5, 10])) isa
          Vector{IS.XY_COORDS}
    @test isapprox(
        collect.(IS.running_sum(IS.PiecewiseStepData([1, 3, 5], [2.5, 10]))),
        collect.([(1, 0), (3, 5), (5, 25)]),
    )

    @test isapprox(
        IS.get_x_lengths(IS.PiecewiseLinearData([(1, 1), (1.1, 2), (1.2, 3)])),
        [0.1, 0.1])
    @test isapprox(
        IS.get_x_lengths(IS.PiecewiseStepData([1, 1.1, 1.2], [1.1, 10])),
        [0.1, 0.1])

    @test IS.is_convex(IS.PiecewiseLinearData([(0, 0), (1, 1), (1.1, 2), (1.2, 3)]))
    @test !IS.is_convex(IS.PiecewiseLinearData([(0, 0), (1, 1), (1.1, 2), (5, 3)]))

    @test IS.is_convex(
        IS.PiecewiseStepData(; x_coords = [0.0, 1.0, 2.0], y_coords = [1.0, 2.0]),
    )
    @test !IS.is_convex(
        IS.PiecewiseStepData(; x_coords = [0.0, 1.0, 2.0], y_coords = [1.0, 0.9]),
    )

    @test IS.is_concave(IS.PiecewiseLinearData([(0, 3), (1, 2), (1.1, 1), (1.2, 0)]))
    @test !IS.is_concave(IS.PiecewiseLinearData([(0, 3), (1, 2), (1.1, 1), (1.2, 5)]))

    @test IS.is_concave(
        IS.PiecewiseStepData(; x_coords = [0.0, 1.0, 2.0], y_coords = [2.0, 1.0]),
    )
    @test !IS.is_concave(
        IS.PiecewiseStepData(; x_coords = [0.0, 1.0, 2.0], y_coords = [0.9, 1.0]),
    )

    @test IS.QuadraticFunctionData(IS.LinearFunctionData(1, 2)) ==
          convert(IS.QuadraticFunctionData, IS.LinearFunctionData(1, 2)) ==
          IS.QuadraticFunctionData(0, 1, 2)

    @test zero(IS.LinearFunctionData(1, 2)) == IS.LinearFunctionData(0, 0)
    @test zero(IS.LinearFunctionData) == IS.LinearFunctionData(0, 0)
    @test zero(IS.FunctionData) == IS.LinearFunctionData(0, 0)
end

@testset "Test PiecewiseLinearData <-> PiecewiseStepData conversion" begin
    rng = Random.Xoshiro(47)  # Set random seed for determinism
    n_tests = 100
    n_points = 10
    for _ in 1:n_tests
        rand_x = sort(rand(rng, n_points))
        rand_y = rand(rng, n_points)
        pointwise = IS.PiecewiseLinearData(collect(zip(rand_x, rand_y)))
        slopewise =
            IS.PiecewiseStepData(IS.get_x_coords(pointwise), IS.get_slopes(pointwise))
        c = first(IS.get_points(pointwise)).y
        pointwise_2 =
            IS.PiecewiseLinearData([(p.x, p.y + c) for p in IS.running_sum(slopewise)])
        @test isapprox(
            collect.(IS.get_points(pointwise_2)), collect.(IS.get_points(pointwise)))
    end
end

@testset "Test FunctionData serialization round trip" begin
    for fd in get_test_function_data()
        for do_jsonify in (false, true)
            serialized = IS.serialize(fd)
            do_jsonify && (serialized = JSON3.read(JSON3.write(serialized), Dict))
            @test typeof(serialized) <: AbstractDict
            deserialized = IS.deserialize(typeof(fd), serialized)
            @test deserialized == fd
        end
    end
end

@testset "Test FunctionData raw data" begin
    raw_data_answers = [
        (5.0, 1.0),
        (2.0, 3.0, 4.0),
        [(1.0, 1.0), (3.0, 5.0), (5.0, 10.0)],
        [1.0 NaN; 3.0 2.0; 5.0 2.5],
    ]
    for (fd, answer) in zip(get_test_function_data(), raw_data_answers)
        @test IS.get_raw_data_type(fd) == typeof(answer)
    end
    for (fd, answer) in zip(get_test_function_data(), raw_data_answers)
        @test IS.get_raw_data_type(typeof(fd)) == typeof(answer)
    end
end

@testset "Test FunctionData equality with NaN" begin
    examples_1 = get_more_test_function_data()
    examples_2 = get_more_test_function_data()

    # Value-equal function data should be == except when containing NaN since NaN != NaN;
    # value-equal function data should be isequal even when containing NaN; hash equality
    # should correspond with isequal
    for my_type in IS.get_all_concrete_subtypes(IS.FunctionData)
        @test examples_1[(my_type, false)] == examples_2[(my_type, false)]
        @test examples_1[(my_type, true)] != examples_2[(my_type, true)]
        @test examples_1[(my_type, false)] != examples_2[(my_type, true)]
        @test isequal(examples_1[(my_type, false)], examples_2[(my_type, false)])
        @test isequal(examples_1[(my_type, true)], examples_2[(my_type, true)])
        @test !isequal(examples_1[(my_type, false)], examples_2[(my_type, true)])
        @test hash(examples_1[(my_type, false)]) == hash(examples_2[(my_type, false)])
        @test hash(examples_1[(my_type, true)]) == hash(examples_2[(my_type, true)])
        @test hash(examples_1[(my_type, false)]) != hash(examples_2[(my_type, true)])
    end
end

@testset "Test FunctionData printing" begin
    repr_answers = [
        "InfrastructureSystems.LinearFunctionData(5.0, 1.0)",
        "InfrastructureSystems.QuadraticFunctionData(2.0, 3.0, 4.0)",
        "InfrastructureSystems.PiecewiseLinearData(@NamedTuple{x::Float64, y::Float64}[(x = 1.0, y = 1.0), (x = 3.0, y = 5.0), (x = 5.0, y = 10.0)])",
        "InfrastructureSystems.PiecewiseStepData([1.0, 3.0, 5.0], [2.0, 2.5])",
    ]
    plain_answers = [
        "InfrastructureSystems.LinearFunctionData representing function f(x) = 5.0 x + 1.0",
        "InfrastructureSystems.QuadraticFunctionData representing function f(x) = 2.0 x^2 + 3.0 x + 4.0",
        "InfrastructureSystems.PiecewiseLinearData representing piecewise linear function y = f(x) connecting points:\n  (x = 1.0, y = 1.0)\n  (x = 3.0, y = 5.0)\n  (x = 5.0, y = 10.0)",
        "InfrastructureSystems.PiecewiseStepData representing step (piecewise constant) function f(x) =\n  2.0 for x in [1.0, 3.0)\n  2.5 for x in [3.0, 5.0)",
    ]
    compact_plain_answers = [
        "f(x) = 5.0 x + 1.0",
        "f(x) = 2.0 x^2 + 3.0 x + 4.0",
        "piecewise linear y = f(x) connecting points:\n  (x = 1.0, y = 1.0)\n  (x = 3.0, y = 5.0)\n  (x = 5.0, y = 10.0)",
        "f(x) =\n  2.0 for x in [1.0, 3.0)\n  2.5 for x in [3.0, 5.0)",
    ]

    for (fd, repr_ans, plain_ans, compact_plain_ans) in
        zip(get_test_function_data(), repr_answers, plain_answers, compact_plain_answers)
        @test sprint(show, fd) == repr(fd) == repr_ans
        @test sprint(show, "text/plain", fd) ==
              sprint(show, "text/plain", fd; context = :compact => false) == plain_ans
        @test sprint(show, "text/plain", fd; context = :compact => true) ==
              compact_plain_ans
    end
end
