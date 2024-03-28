get_test_function_data() = [
    IS.LinearFunctionData(5, 1),
    IS.QuadraticFunctionData(2, 3, 4),
    IS.PiecewiseLinearData([(1, 1), (3, 5), (5, 10)]),
    IS.PiecewiseStepData([1, 3, 5], [2, 2.5], 1),
]

@testset "Test FunctionData constructors" begin
    @test all(isa.(get_test_function_data(), IS.FunctionData))
    @test IS.LinearFunctionData(5) isa IS.FunctionData
    @test IS.PiecewiseStepData([1, 3, 5], [2, 2.5], nothing) isa IS.FunctionData
    @test IS.PiecewiseStepData([1, 3, 5], [2, 2.5]) isa IS.FunctionData
end

@testset "Test FunctionData validation" begin
    # x-coordinates need to be sorted
    @test_throws ArgumentError IS.PiecewiseLinearData([(2, 1), (1, 1)])
    @test_throws ArgumentError IS.PiecewiseStepData([2, 1], [1], 1)
    
    @test IS.PiecewiseLinearData([(x = 1, y = 1)]) isa Any  # Test absence of error
    @test IS.PiecewiseLinearData([Dict("x" => 1, "y" => 1)]) isa Any
    @test_throws ArgumentError IS.PiecewiseLinearData([(y = 1, x = 1)])
    @test_throws ArgumentError IS.PiecewiseLinearData([Dict("x" => 1)])
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

    dd = IS.PiecewiseStepData([1, 3, 5], [3, 6], 2)
    @test IS.get_x_coords(dd) == [1, 3, 5]
    @test IS.get_y_coords(dd) == [3, 6]
    @test IS.get_c(dd) == 2
end

@testset "Test FunctionData calculations" begin
    @test length(IS.PiecewiseLinearData([(0, 0), (1, 1), (1.1, 2)])) == 2
    @test length(IS.PiecewiseStepData([1, 1.1, 1.2], [1.1, 10], 1)) == 2

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

    integral = IS.integrate(IS.PiecewiseStepData([1, 3, 5], [2.5, 10], 1))
    @test integral isa IS.PiecewiseLinearData
    @test isapprox(
        collect.(IS.get_points(integral)),
        collect.([(1, 1), (3, 6), (5, 26)]),
    )

    @test isapprox(
        IS.get_x_lengths(IS.PiecewiseLinearData([(1, 1), (1.1, 2), (1.2, 3)])),
        [0.1, 0.1])
    @test isapprox(
        IS.get_x_lengths(IS.PiecewiseStepData([1, 1.1, 1.2], [1.1, 10], 1)),
        [0.1, 0.1])

    @test IS.is_convex(IS.PiecewiseLinearData([(0, 0), (1, 1), (1.1, 2), (1.2, 3)]))
    @test !IS.is_convex(IS.PiecewiseLinearData([(0, 0), (1, 1), (1.1, 2), (5, 3)]))
end

@testset "Test PiecewiseLinearData <-> PiecewiseStepData conversion" begin
    rng = Random.Xoshiro(47)  # Set random seed for determinism
    n_tests = 100
    n_points = 10
    for _ in 1:n_tests
        rand_x = sort(rand(rng, n_points))
        rand_y = rand(rng, n_points)
        pointwise = IS.PiecewiseLinearData(collect(zip(rand_x, rand_y)))
        slopewise = IS.differentiate(pointwise)
        pointwise_2 = IS.integrate(slopewise)
        @test isapprox(
            collect.(IS.get_points(pointwise_2)), collect.(IS.get_points(pointwise)))
        # Fundamental theorem of calculus is experimentally verified :)
    end

    @test_throws ArgumentError IS.integrate(IS.PiecewiseStepData([1, 3, 5], [2, 2.5]))
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
