get_test_function_data() = [
    IS.LinearFunctionData(5, 1),
    IS.QuadraticFunctionData(2, 3, 4),
    IS.PiecewiseLinearData([(1, 1), (3, 5), (5, 10)]),
    IS.PiecewiseStepData([1, 3, 5], [2, 2.5]),
]

get_test_function_data_zeros() = [
    IS.LinearFunctionData(0.0, 0.0),
    IS.QuadraticFunctionData(0.0, 0.0, 0.0),
    IS.PiecewiseLinearData([(1.0, 0.0), (3.0, 0.0), (5.0, 0.0)]),
    IS.PiecewiseStepData([1.0, 3.0, 5.0], [0.0, 0.0]),
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

@testset "Test FunctionData core calculations" begin
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

    convex_pld = IS.PiecewiseLinearData([(0, 0), (1, 1), (1.1, 2), (1.2, 3)])
    non_convex_pld = IS.PiecewiseLinearData([(0, 0), (1, 1), (1.1, 2), (5, 3)])

    @test IS.is_convex(convex_pld)
    @test !IS.is_convex(non_convex_pld)

    @test IS.is_convex(IS.InputOutputCurve(convex_pld))
    @test !IS.is_convex(IS.InputOutputCurve(non_convex_pld))

    @test IS.is_convex(IS.CostCurve(IS.InputOutputCurve(convex_pld)))
    @test !IS.is_convex(IS.CostCurve(IS.InputOutputCurve(non_convex_pld)))

    @test IS.is_convex(
        IS.PiecewiseStepData(; x_coords = [0.0, 1.0, 2.0], y_coords = [1.0, 2.0]),
    )
    @test !IS.is_convex(
        IS.PiecewiseStepData(; x_coords = [0.0, 1.0, 2.0], y_coords = [1.0, 0.9]),
    )

    concave_pld = IS.PiecewiseLinearData([(0, 3), (1, 2), (1.1, 1), (1.2, 0)])
    non_concave_pld = IS.PiecewiseLinearData([(0, 3), (1, 2), (1.1, 1), (1.2, 5)])

    @test IS.is_concave(concave_pld)
    @test !IS.is_concave(non_concave_pld)

    @test IS.is_concave(IS.InputOutputCurve(concave_pld))
    @test !IS.is_concave(IS.InputOutputCurve(non_concave_pld))

    @test IS.is_concave(IS.CostCurve(IS.InputOutputCurve(concave_pld)))
    @test !IS.is_concave(IS.CostCurve(IS.InputOutputCurve(non_concave_pld)))

    @test IS.is_concave(
        IS.PiecewiseStepData(; x_coords = [0.0, 1.0, 2.0], y_coords = [2.0, 1.0]),
    )
    @test !IS.is_concave(
        IS.PiecewiseStepData(; x_coords = [0.0, 1.0, 2.0], y_coords = [0.9, 1.0]),
    )

    @test IS.QuadraticFunctionData(IS.LinearFunctionData(1, 2)) ==
          convert(IS.QuadraticFunctionData, IS.LinearFunctionData(1, 2)) ==
          IS.QuadraticFunctionData(0, 1, 2)

    @test IS.get_domain(IS.LinearFunctionData(1, 2)) == (-Inf, Inf)
    @test IS.get_domain(IS.QuadraticFunctionData(1, 2, 3)) == (-Inf, Inf)
    @test IS.get_domain(IS.PiecewiseLinearData([(1, 1), (3, 1), (5, 1)])) == (1, 5)
    @test IS.get_domain(IS.PiecewiseStepData([1, 3, 5], [1, 1])) == (1, 5)

    for (fd, answer) in zip(get_test_function_data(), get_test_function_data_zeros())
        @test zero(fd) == answer
    end

    @test zero(IS.LinearFunctionData) == IS.LinearFunctionData(0, 0)
    @test zero(IS.QuadraticFunctionData) == IS.QuadraticFunctionData(0, 0, 0)
    @test zero(IS.PiecewiseLinearData) == IS.PiecewiseLinearData([(-Inf, 0), (Inf, 0)])
    @test zero(IS.PiecewiseStepData) == IS.PiecewiseStepData([-Inf, Inf], [0.0])
    @test zero(IS.PiecewiseLinearData; domain = (1.0, 5.0)) ==
          IS.PiecewiseLinearData([(1.0, 0), (5.0, 0)])
    @test zero(IS.PiecewiseStepData; domain = (1.0, 5.0)) ==
          IS.PiecewiseStepData([1.0, 5.0], [0.0])
    @test zero(IS.FunctionData) == IS.LinearFunctionData(0, 0)
end

@testset "Test FunctionData higher-level arithmetic" begin
    # SCALAR MULTIPLICATION AND UNARY NEGATION
    # Test scalar multiplication for LinearFunctionData
    ld = IS.LinearFunctionData(5, 1)  # f(x) = 5x + 1
    ld_scaled = 3.0 * ld
    @test ld_scaled isa IS.LinearFunctionData
    @test IS.get_proportional_term(ld_scaled) == 15.0  # 3 * 5
    @test IS.get_constant_term(ld_scaled) == 3.0       # 3 * 1

    # Test scalar multiplication for QuadraticFunctionData
    qd = IS.QuadraticFunctionData(2, 3, 4)  # f(x) = 2x^2 + 3x + 4
    qd_scaled = 2.5 * qd
    @test qd_scaled isa IS.QuadraticFunctionData
    @test IS.get_quadratic_term(qd_scaled) == 5.0    # 2.5 * 2
    @test IS.get_proportional_term(qd_scaled) == 7.5 # 2.5 * 3
    @test IS.get_constant_term(qd_scaled) == 10.0    # 2.5 * 4

    # Test scalar multiplication for PiecewiseLinearData
    pld = IS.PiecewiseLinearData([(1, 2), (3, 6), (5, 10)])
    pld_scaled = 0.5 * pld
    @test pld_scaled isa IS.PiecewiseLinearData
    expected_points = [(x = 1.0, y = 1.0), (x = 3.0, y = 3.0), (x = 5.0, y = 5.0)]
    @test IS.get_points(pld_scaled) == expected_points
    @test IS.get_x_coords(pld_scaled) == [1, 3, 5]  # x-coordinates unchanged
    @test IS.get_y_coords(pld_scaled) == [1.0, 3.0, 5.0]  # y-coordinates scaled

    # Test scalar multiplication for PiecewiseStepData
    psd = IS.PiecewiseStepData([1, 3, 5], [4, 8])
    psd_scaled = 0.25 * psd
    @test psd_scaled isa IS.PiecewiseStepData
    @test IS.get_x_coords(psd_scaled) == [1, 3, 5]  # x-coordinates unchanged
    @test IS.get_y_coords(psd_scaled) == [1.0, 2.0]  # y-coordinates scaled: [0.25*4, 0.25*8]

    # Test commutativity of scalar multiplication
    scalars = [3.0, 2.5, 0.5, 0.25]
    for (fd, scalar) in zip(get_test_function_data(), scalars)
        @test fd * scalar == scalar * fd
    end

    # Test multiplication by zero
    for (fd, answer) in zip(get_test_function_data(), get_test_function_data_zeros())
        fd_zero = 0.0 * fd
        @test fd_zero isa typeof(fd)
        @test fd_zero == answer
    end

    # Test multiplication by one (identity)
    for fd in get_test_function_data()
        fd_identity = 1.0 * fd
        @test fd_identity == fd
        @test fd * 1.0 == fd
    end

    # Test multiplication by negative scalar and unary negation
    for fd in get_test_function_data()
        fd_neg = -1.0 * fd
        @test fd_neg isa typeof(fd)
        if fd isa IS.LinearFunctionData
            @test IS.get_proportional_term(fd_neg) == -IS.get_proportional_term(fd)
            @test IS.get_constant_term(fd_neg) == -IS.get_constant_term(fd)
        elseif fd isa IS.QuadraticFunctionData
            @test IS.get_quadratic_term(fd_neg) == -IS.get_quadratic_term(fd)
            @test IS.get_proportional_term(fd_neg) == -IS.get_proportional_term(fd)
            @test IS.get_constant_term(fd_neg) == -IS.get_constant_term(fd)
        elseif fd isa IS.PiecewiseLinearData
            orig_points = IS.get_points(fd)
            neg_points = IS.get_points(fd_neg)
            for (orig, neg) in zip(orig_points, neg_points)
                @test orig.x == neg.x
                @test orig.y == -neg.y
            end
        elseif fd isa IS.PiecewiseStepData
            @test IS.get_x_coords(fd_neg) == IS.get_x_coords(fd)
            @test IS.get_y_coords(fd_neg) == -IS.get_y_coords(fd)
        end

        @test -fd == fd_neg
    end

    # SCALAR ADDITION
    # Test scalar addition for LinearFunctionData
    ld = IS.LinearFunctionData(5, 1)  # f(x) = 5x + 1
    ld_plus_scalar = ld + 3.0         # (f + 3)(x) = 5x + 4
    @test ld_plus_scalar isa IS.LinearFunctionData
    @test IS.get_proportional_term(ld_plus_scalar) == 5.0  # unchanged
    @test IS.get_constant_term(ld_plus_scalar) == 4.0      # 1 + 3

    # Test scalar addition for QuadraticFunctionData
    qd = IS.QuadraticFunctionData(2, 3, 4)  # f(x) = 2x^2 + 3x + 4
    qd_plus_scalar = qd + 2.5               # (f + 2.5)(x) = 2x^2 + 3x + 6.5
    @test qd_plus_scalar isa IS.QuadraticFunctionData
    @test IS.get_quadratic_term(qd_plus_scalar) == 2.0      # unchanged
    @test IS.get_proportional_term(qd_plus_scalar) == 3.0   # unchanged
    @test IS.get_constant_term(qd_plus_scalar) == 6.5       # 4 + 2.5

    # Test scalar addition for PiecewiseLinearData
    pld = IS.PiecewiseLinearData([(1, 2), (3, 6), (5, 10)])
    pld_plus_scalar = pld + 1.5
    @test pld_plus_scalar isa IS.PiecewiseLinearData
    expected_points = [(x = 1.0, y = 3.5), (x = 3.0, y = 7.5), (x = 5.0, y = 11.5)]
    @test IS.get_points(pld_plus_scalar) == expected_points
    @test IS.get_x_coords(pld_plus_scalar) == [1, 3, 5]  # x-coordinates unchanged
    @test IS.get_y_coords(pld_plus_scalar) == [3.5, 7.5, 11.5]  # y-coordinates shifted up

    # Test scalar addition for PiecewiseStepData
    psd = IS.PiecewiseStepData([1, 3, 5], [4, 8])
    psd_plus_scalar = psd + 0.5
    @test psd_plus_scalar isa IS.PiecewiseStepData
    @test IS.get_x_coords(psd_plus_scalar) == [1, 3, 5]    # x-coordinates unchanged
    @test IS.get_y_coords(psd_plus_scalar) == [4.5, 8.5]   # y-coordinates shifted up: [4+0.5, 8+0.5]

    # Test commutativity of scalar addition (f + c = c + f)
    scalars = [3.0, 2.5, 1.5, 0.5]
    for (fd, scalar) in zip(get_test_function_data(), scalars)
        @test fd + scalar == scalar + fd
    end

    # Test adding zero (identity)
    for fd in get_test_function_data()
        @test fd + 0.0 == fd
        @test 0.0 + fd == fd
    end

    # Test adding negative scalar
    for fd in get_test_function_data()
        fd_minus_one = fd + (-1.0)
        @test fd_minus_one isa typeof(fd)
        if fd isa IS.LinearFunctionData
            @test IS.get_proportional_term(fd_minus_one) == IS.get_proportional_term(fd)
            @test IS.get_constant_term(fd_minus_one) == IS.get_constant_term(fd) - 1.0
        elseif fd isa IS.QuadraticFunctionData
            @test IS.get_quadratic_term(fd_minus_one) == IS.get_quadratic_term(fd)
            @test IS.get_proportional_term(fd_minus_one) == IS.get_proportional_term(fd)
            @test IS.get_constant_term(fd_minus_one) == IS.get_constant_term(fd) - 1.0
        elseif fd isa IS.PiecewiseLinearData
            orig_points = IS.get_points(fd)
            shifted_points = IS.get_points(fd_minus_one)
            for (orig, shifted) in zip(orig_points, shifted_points)
                @test orig.x == shifted.x
                @test orig.y - 1.0 == shifted.y
            end
        elseif fd isa IS.PiecewiseStepData
            @test IS.get_x_coords(fd_minus_one) == IS.get_x_coords(fd)
            @test IS.get_y_coords(fd_minus_one) == IS.get_y_coords(fd) .- 1.0
        end
    end

    # SHIFT BY A SCALAR
    # Test right shift for LinearFunctionData
    ld = IS.LinearFunctionData(5, 1)  # f(x) = 5x + 1
    ld_shifted = ld >> 2.0            # (f >> 2)(x) = f(x - 2) = 5(x - 2) + 1 = 5x - 9
    @test ld_shifted isa IS.LinearFunctionData
    @test IS.get_proportional_term(ld_shifted) == 5.0   # unchanged
    @test IS.get_constant_term(ld_shifted) == -9.0      # 1 - 5*2

    # Test right shift for QuadraticFunctionData
    qd = IS.QuadraticFunctionData(2, 3, 4)  # f(x) = 2x^2 + 3x + 4
    qd_shifted = qd >> 1.0                  # (f >> 1)(x) = f(x - 1) = 2(x-1)^2 + 3(x-1) + 4 = 2x^2 - x + 3
    @test qd_shifted isa IS.QuadraticFunctionData
    @test IS.get_quadratic_term(qd_shifted) == 2.0       # unchanged
    @test IS.get_proportional_term(qd_shifted) == -1.0    # 3 - 2*2*1
    @test IS.get_constant_term(qd_shifted) == 3.0        # 4 + 2*1^2 - 3*1

    # Another quadratic case
    qd2 = IS.QuadraticFunctionData(1, -2, 5)  # g(x) = x^2 - 2x + 5
    qd2_shifted = qd2 >> 3.0                  # (g >> 3)(x) = g(x - 3) = (x-3)^2 - 2(x-3) + 5 = x^2 - 8x + 20
    @test qd2_shifted isa IS.QuadraticFunctionData
    @test IS.get_quadratic_term(qd2_shifted) == 1.0      # unchanged
    @test IS.get_proportional_term(qd2_shifted) == -8.0  # -2 - 2*1*3 = -2 - 6 = -8
    @test IS.get_constant_term(qd2_shifted) == 20.0      # 5 + 1*3^2 - (-2)*3 = 5 + 9 + 6 = 20

    # Test right shift for PiecewiseLinearData
    pld = IS.PiecewiseLinearData([(1, 2), (3, 6), (5, 10)])
    pld_shifted = pld >> 1.5  # shifts x-coordinates right by 1.5
    @test pld_shifted isa IS.PiecewiseLinearData
    expected_points = [(x = 2.5, y = 2.0), (x = 4.5, y = 6.0), (x = 6.5, y = 10.0)]
    @test IS.get_points(pld_shifted) == expected_points
    @test IS.get_x_coords(pld_shifted) == [2.5, 4.5, 6.5]  # x-coordinates shifted
    @test IS.get_y_coords(pld_shifted) == [2.0, 6.0, 10.0]  # y-coordinates unchanged

    # Test right shift for PiecewiseStepData
    psd = IS.PiecewiseStepData([1, 3, 5], [4, 8])
    psd_shifted = psd >> 0.5  # shifts x-coordinates right by 0.5
    @test psd_shifted isa IS.PiecewiseStepData
    @test IS.get_x_coords(psd_shifted) == [1.5, 3.5, 5.5]  # x-coordinates shifted
    @test IS.get_y_coords(psd_shifted) == [4, 8]           # y-coordinates unchanged

    # Test left shift (f << c = f >> -c)
    shifts = [2.0, 1.0, 1.5, 0.5]
    for (fd, shift) in zip(get_test_function_data(), shifts)
        @test fd << shift == fd >> (-shift)
    end

    # Test shifting by zero (identity)
    for fd in get_test_function_data()
        @test fd >> 0.0 == fd
        @test fd << 0.0 == fd
    end

    # Test double shift equivalence: (f >> a) >> b = f >> (a + b)
    for fd in get_test_function_data()
        a, b = 1.0, 2.0
        @test (fd >> a) >> b == fd >> (a + b)
        @test (fd << a) << b == fd << (a + b)
    end

    # Test shift then reverse shift (should return to original)
    shifts = [1.0, 2.5, 0.75, 3.0]
    for (fd, shift) in zip(get_test_function_data(), shifts)
        shifted_back = (fd >> shift) << shift
        if fd isa Union{IS.LinearFunctionData, IS.QuadraticFunctionData}
            # For polynomial functions, use approximate equality due to floating point arithmetic
            if fd isa IS.LinearFunctionData
                @test isapprox(
                    IS.get_proportional_term(shifted_back),
                    IS.get_proportional_term(fd),
                )
                @test isapprox(IS.get_constant_term(shifted_back), IS.get_constant_term(fd))
            else  # QuadraticFunctionData
                @test isapprox(
                    IS.get_quadratic_term(shifted_back),
                    IS.get_quadratic_term(fd),
                )
                @test isapprox(
                    IS.get_proportional_term(shifted_back),
                    IS.get_proportional_term(fd),
                )
                @test isapprox(IS.get_constant_term(shifted_back), IS.get_constant_term(fd))
            end
        else
            # For piecewise functions, exact equality should hold
            @test shifted_back == fd
        end
    end

    # FLIP ABOUT Y-AXIS
    # Test flip for LinearFunctionData
    ld = IS.LinearFunctionData(5, 1)  # f(x) = 5x + 1
    ld_flipped = ~ld                  # (~f)(x) = f(-x) = 5(-x) + 1 = -5x + 1
    @test ld_flipped isa IS.LinearFunctionData
    @test IS.get_proportional_term(ld_flipped) == -5.0  # -5
    @test IS.get_constant_term(ld_flipped) == 1.0       # unchanged

    # Test flip for QuadraticFunctionData
    qd = IS.QuadraticFunctionData(2, 3, 4)  # f(x) = 2x^2 + 3x + 4
    qd_flipped = ~qd                        # (~f)(x) = f(-x) = 2(-x)^2 + 3(-x) + 4 = 2x^2 - 3x + 4
    @test qd_flipped isa IS.QuadraticFunctionData
    @test IS.get_quadratic_term(qd_flipped) == 2.0      # unchanged (even power)
    @test IS.get_proportional_term(qd_flipped) == -3.0  # -3 (odd power)
    @test IS.get_constant_term(qd_flipped) == 4.0       # unchanged

    # Test flip for PiecewiseLinearData
    pld = IS.PiecewiseLinearData([(1, 2), (3, 6), (5, 10)])
    pld_flipped = ~pld  # flips x-coordinates and reverses order
    @test pld_flipped isa IS.PiecewiseLinearData
    expected_points = [(x = -5.0, y = 10.0), (x = -3.0, y = 6.0), (x = -1.0, y = 2.0)]
    @test IS.get_points(pld_flipped) == expected_points
    @test IS.get_x_coords(pld_flipped) == [-5.0, -3.0, -1.0]  # negated and reversed
    @test IS.get_y_coords(pld_flipped) == [10.0, 6.0, 2.0]    # reversed

    # Test flip for PiecewiseStepData
    psd = IS.PiecewiseStepData([1, 3, 5], [4, 8])
    psd_flipped = ~psd  # flips x-coordinates and reverses both x and y arrays
    @test psd_flipped isa IS.PiecewiseStepData
    @test IS.get_x_coords(psd_flipped) == [-5, -3, -1]  # negated and reversed
    @test IS.get_y_coords(psd_flipped) == [8, 4]        # reversed

    # Test double flip returns to original
    for fd in get_test_function_data()
        double_flipped = ~(~fd)
        @test double_flipped == fd
    end

    # ADDITION OF TWO FUNCTIONDATAS
    # Test addition for LinearFunctionData
    ld1 = IS.LinearFunctionData(5, 1)   # f(x) = 5x + 1
    ld2 = IS.LinearFunctionData(3, 2)   # g(x) = 3x + 2
    ld_sum = ld1 + ld2                  # (f+g)(x) = 8x + 3
    @test ld_sum isa IS.LinearFunctionData
    @test IS.get_proportional_term(ld_sum) == 8.0  # 5 + 3
    @test IS.get_constant_term(ld_sum) == 3.0       # 1 + 2

    # Test addition for QuadraticFunctionData
    qd1 = IS.QuadraticFunctionData(2, 3, 4)  # f(x) = 2x^2 + 3x + 4
    qd2 = IS.QuadraticFunctionData(1, 2, 1)  # g(x) = x^2 + 2x + 1
    qd_sum = qd1 + qd2                       # (f+g)(x) = 3x^2 + 5x + 5
    @test qd_sum isa IS.QuadraticFunctionData
    @test IS.get_quadratic_term(qd_sum) == 3.0      # 2 + 1
    @test IS.get_proportional_term(qd_sum) == 5.0   # 3 + 2
    @test IS.get_constant_term(qd_sum) == 5.0       # 4 + 1

    # Test addition for PiecewiseLinearData with same x-coordinates
    pld1 = IS.PiecewiseLinearData([(1, 2), (3, 6), (5, 10)])
    pld2 = IS.PiecewiseLinearData([(1, 1), (3, 2), (5, 3)])
    pld_sum = pld1 + pld2
    @test pld_sum isa IS.PiecewiseLinearData
    expected_points = [(x = 1.0, y = 3.0), (x = 3.0, y = 8.0), (x = 5.0, y = 13.0)]
    @test IS.get_points(pld_sum) == expected_points
    @test IS.get_x_coords(pld_sum) == [1, 3, 5]
    @test IS.get_y_coords(pld_sum) == [3.0, 8.0, 13.0]

    # Test addition for PiecewiseStepData with same x-coordinates
    psd1 = IS.PiecewiseStepData([1, 3, 5], [4, 8])
    psd2 = IS.PiecewiseStepData([1, 3, 5], [2, 3])
    psd_sum = psd1 + psd2
    @test psd_sum isa IS.PiecewiseStepData
    @test IS.get_x_coords(psd_sum) == [1, 3, 5]
    @test IS.get_y_coords(psd_sum) == [6.0, 11.0]  # [4+2, 8+3]

    # Test addition errors for PiecewiseLinearData with different x-coordinates
    pld_diff = IS.PiecewiseLinearData([(1, 1), (2, 2), (4, 4)])  # different x-coords
    @test_throws ArgumentError pld1 + pld_diff

    # Test addition errors for PiecewiseStepData with different x-coordinates
    psd_diff = IS.PiecewiseStepData([1, 2, 4], [1, 2])  # different x-coords
    @test_throws ArgumentError psd1 + psd_diff

    # Test commutativity of addition (f + g = g + f)
    @test ld1 + ld2 == ld2 + ld1
    @test qd1 + qd2 == qd2 + qd1
    @test pld1 + pld2 == pld2 + pld1
    @test psd1 + psd2 == psd2 + psd1

    # Test associativity of addition ((f + g) + h = f + (g + h))
    ld3 = IS.LinearFunctionData(1, 3)
    @test (ld1 + ld2) + ld3 == ld1 + (ld2 + ld3)

    qd3 = IS.QuadraticFunctionData(1, 1, 2)
    @test (qd1 + qd2) + qd3 == qd1 + (qd2 + qd3)

    pld3 = IS.PiecewiseLinearData([(1, 0.5), (3, 1.5), (5, 2.5)])
    @test (pld1 + pld2) + pld3 == pld1 + (pld2 + pld3)

    psd3 = IS.PiecewiseStepData([1, 3, 5], [1, 1])
    @test (psd1 + psd2) + psd3 == psd1 + (psd2 + psd3)
end

@testset "Test FunctionData evaluation" begin
    # Test LinearFunctionData evaluation
    ld = IS.LinearFunctionData(5, 1)  # f(x) = 5x + 1
    @test ld(0) == 1.0      # f(0) = 5*0 + 1 = 1
    @test ld(2) == 11.0     # f(2) = 5*2 + 1 = 11
    @test ld(-1) == -4.0    # f(-1) = 5*(-1) + 1 = -4
    @test ld(1.5) == 8.5    # f(1.5) = 5*1.5 + 1 = 8.5

    # Test QuadraticFunctionData evaluation
    qd = IS.QuadraticFunctionData(2, 3, 4)  # f(x) = 2x^2 + 3x + 4
    @test qd(0) == 4.0      # f(0) = 2*0^2 + 3*0 + 4 = 4
    @test qd(1) == 9.0      # f(1) = 2*1^2 + 3*1 + 4 = 9
    @test qd(-1) == 3.0     # f(-1) = 2*(-1)^2 + 3*(-1) + 4 = 3
    @test qd(2) == 18.0     # f(2) = 2*2^2 + 3*2 + 4 = 18
    @test qd(0.5) == 6.0    # f(0.5) = 2*0.25 + 3*0.5 + 4 = 6

    # Test PiecewiseLinearData evaluation
    pld = IS.PiecewiseLinearData([(1, 2), (3, 6), (5, 10)])
    @test pld(1) == 2.0     # at first point
    @test pld(3) == 6.0     # at middle point
    @test pld(5) == 10.0    # at last point
    @test pld(2) == 4.0     # interpolated: halfway between (1,2) and (3,6)
    @test pld(4) == 8.0     # interpolated: halfway between (3,6) and (5,10)
    @test pld(1.5) == 3.0   # interpolated: 1/4 way from (1,2) to (3,6)

    # Test PiecewiseStepData evaluation
    psd = IS.PiecewiseStepData([1, 3, 5], [4, 8])
    @test psd(1) == 4       # at first x-coordinate
    @test psd(2) == 4       # in first interval [1, 3)
    @test psd(2.9) == 4     # still in first interval
    @test psd(3) == 8       # at second x-coordinate
    @test psd(4) == 8       # in second interval [3, 5)
    @test psd(5) == 8       # at last x-coordinate

    # Test domain checking for piecewise functions
    @test_throws ArgumentError pld(0.5)  # below domain
    @test_throws ArgumentError pld(5.5)  # above domain
    @test_throws ArgumentError psd(0.5)  # below domain
    @test_throws ArgumentError psd(5.5)  # above domain

    # Test evaluation with various numeric types
    for fd in [ld, qd, pld, psd]
        @test fd(2) == fd(2.0) == fd(2 // 1)  # Int, Float64, Rational
    end

    # Test evaluation with complex numbers
    # LinearFunctionData: f(x) = 5x + 1
    @test ld(1 + 2im) == 6 + 10im  # 5*(1 + 2im) + 1
    @test ld(2 - im) == 11 - 5im  # 5*(2 - im) + 1

    # QuadraticFunctionData: f(x) = 2x^2 + 3x + 4
    @test qd(1im) == 2 + 3im  # 2*(1im)^2 + 3*(1im) + 4
    @test qd(1 + im) == 7 + 7im  # 2*(1 + im)^2 + 3*(1 + im) + 4

    # Test consistency: evaluation after mathematical operations
    ld1 = IS.LinearFunctionData(2, 1)  # f(x) = 2x + 1
    ld2 = IS.LinearFunctionData(3, 2)  # g(x) = 3x + 2
    x_test = 1.5

    # Test that (f + g)(x) = f(x) + g(x)
    sum_fd = ld1 + ld2
    @test sum_fd(x_test) ≈ ld1(x_test) + ld2(x_test)

    # Test that (c * f)(x) = c * f(x)
    scaled_fd = 2.5 * ld1
    @test scaled_fd(x_test) ≈ 2.5 * ld1(x_test)

    # Test that (f + c)(x) = f(x) + c
    shifted_fd = ld1 + 3.0
    @test shifted_fd(x_test) ≈ ld1(x_test) + 3.0
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
