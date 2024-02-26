get_test_function_data() = [
    IS.LinearFunctionData(5),
    IS.QuadraticFunctionData(2, 3, 4),
    IS.PolynomialFunctionData(Dict(0 => 3.0, 1 => 1.0, 3 => 4.0)),
    IS.PiecewiseLinearPointData([(1, 1), (3, 5), (5, 10)]),
    IS.PiecewiseLinearSlopeData([1, 3, 5], 1, [2, 2.5]),
]

@testset "Test FunctionData validation" begin
    @test_throws ArgumentError IS.PiecewiseLinearPointData([(2, 1), (1, 1)])
    @test_throws ArgumentError IS.PiecewiseLinearSlopeData([2, 1], 1, [1])

    @test IS.PiecewiseLinearPointData([(x = 1, y = 1)]) isa Any  # Test absence of error
    @test IS.PiecewiseLinearPointData([Dict("x" => 1, "y" => 1)]) isa Any
    @test_throws ArgumentError IS.PiecewiseLinearPointData([(y = 1, x = 1)])
    @test_throws ArgumentError IS.PiecewiseLinearPointData([Dict("x" => 1)])
end

@testset "Test FunctionData trivial getters" begin
    ld = IS.LinearFunctionData(5)
    @test IS.get_proportional_term(ld) == 5

    qd = IS.QuadraticFunctionData(2, 3, 4)
    @test IS.get_quadratic_term(qd) == 2
    @test IS.get_proportional_term(qd) == 3
    @test IS.get_constant_term(qd) == 4

    pd = IS.PolynomialFunctionData(Dict(0 => 3.0, 1 => 1.0, 3 => 4.0))
    coeffs = IS.get_coefficients(pd)
    @test length(coeffs) == 3
    @test coeffs[0] === 3.0 && coeffs[1] === 1.0 && coeffs[3] === 4.0

    yd = IS.PiecewiseLinearPointData([(1, 1), (3, 5)])
    @test IS.get_points(yd) == [(x = 1, y = 1), (x = 3, y = 5)]

    dd = IS.PiecewiseLinearSlopeData([1, 3, 5], 2, [3, 6])
    @test IS.get_x_coords(dd) == [1, 3, 5]
    @test IS.get_y0(dd) == 2
    @test IS.get_slopes(dd) == [3, 6]
end

@testset "Test FunctionData calculations" begin
    @test length(IS.PiecewiseLinearPointData([(0, 0), (1, 1), (1.1, 2)])) == 2
    @test length(IS.PiecewiseLinearSlopeData([1, 1.1, 1.2], 1, [1.1, 10])) == 2

    @test IS.PiecewiseLinearPointData([(0, 0), (1, 1), (1.1, 2)])[2] == (x = 1, y = 1)
    @test IS.get_x_coords(IS.PiecewiseLinearPointData([(0, 0), (1, 1), (1.1, 2)])) ==
          [0, 1, 1.1]

    # Tests our overridden Base.:(==)
    @test all(get_test_function_data() .== get_test_function_data())

    @test all(
        isapprox.(
            IS.get_slopes(IS.PiecewiseLinearPointData([(0, 0), (10, 31.4)])), [3.14]),
    )
    @test isapprox(
        IS.get_slopes(IS.PiecewiseLinearPointData([(0, 0), (1, 1), (1.1, 2), (1.2, 3)])),
        [1, 10, 10])
    @test isapprox(
        IS.get_slopes(IS.PiecewiseLinearPointData([(0, 0), (1, 1), (1.1, 2)])),
        [1, 10])

    @test IS.get_points(IS.PiecewiseLinearSlopeData([1, 3, 5], 1, [2.5, 10])) isa
          Vector{@NamedTuple{x::Float64, y::Float64}}
    @test isapprox(
        collect.(IS.get_points(IS.PiecewiseLinearSlopeData([1, 3, 5], 1, [2.5, 10]))),
        collect.([(1, 1), (3, 6), (5, 26)]),
    )

    @test isapprox(
        IS.get_x_lengths(IS.PiecewiseLinearPointData([(1, 1), (1.1, 2), (1.2, 3)])),
        [0.1, 0.1])
    @test isapprox(
        IS.get_x_lengths(IS.PiecewiseLinearSlopeData([1, 1.1, 1.2], 1, [1.1, 10])),
        [0.1, 0.1])

    @test IS.is_convex(IS.PiecewiseLinearSlopeData([0, 1, 1.1, 1.2], 1, [1.1, 10, 10]))
    @test !IS.is_convex(IS.PiecewiseLinearSlopeData([0, 1, 1.1, 1.2], 1, [1.1, 10, 9]))
    @test IS.is_convex(IS.PiecewiseLinearPointData([(0, 0), (1, 1), (1.1, 2), (1.2, 3)]))
    @test !IS.is_convex(IS.PiecewiseLinearPointData([(0, 0), (1, 1), (1.1, 2), (5, 3)]))
end

@testset "Test FunctionData piecewise point/slope conversion" begin
    rng = Random.Xoshiro(47)  # Set random seed for determinism
    n_tests = 100
    n_points = 10
    for _ in 1:n_tests
        rand_x = sort(rand(rng, n_points))
        rand_y = rand(rng, n_points)
        pointwise = IS.PiecewiseLinearPointData(collect(zip(rand_x, rand_y)))
        slopewise = IS.PiecewiseLinearSlopeData(
            IS.get_x_coords(pointwise),
            first(IS.get_points(pointwise)).y,
            IS.get_slopes(pointwise))
        pointwise_2 = IS.PiecewiseLinearPointData(IS.get_points(slopewise))
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
        5.0,
        (2.0, 3.0, 4.0),
        [(0, 3.0), (1, 1.0), (3, 4.0)],
        [(1.0, 1.0), (3.0, 5.0), (5.0, 10.0)],
        [(1.0, 1.0), (3.0, 2.0), (5.0, 2.5)],
    ]
    for (fd, answer) in zip(get_test_function_data(), raw_data_answers)
        @test IS.get_raw_data_type(fd) == typeof(answer)
    end
    for (fd, answer) in zip(get_test_function_data(), raw_data_answers)
        @test IS.get_raw_data_type(typeof(fd)) == typeof(answer)
    end
    for (fd, answer) in zip(get_test_function_data(), raw_data_answers)
        @test IS.get_raw_data(fd) == answer
    end
end
