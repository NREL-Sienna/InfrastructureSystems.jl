@testset "Test Convexity Checks" begin
    # LinearFunctionData
    lfd = IS.LinearFunctionData(5.0, 1.0)
    @test IS.is_convex(lfd)

    # QuadraticFunctionData
    qfd_convex = IS.QuadraticFunctionData(2.0, 3.0, 4.0)  # a > 0
    @test IS.is_convex(qfd_convex)

    qfd_concave = IS.QuadraticFunctionData(-2.0, 3.0, 4.0)  # a < 0
    @test !IS.is_convex(qfd_concave)

    qfd_linear = IS.QuadraticFunctionData(0.0, 3.0, 4.0)  # a = 0
    @test IS.is_convex(qfd_linear)

    # PiecewiseLinearData
    # Convex: slopes increasing (1.0, 2.0)
    pld_convex =
        IS.PiecewiseLinearData([(x = 0.0, y = 0.0), (x = 1.0, y = 1.0), (x = 2.0, y = 3.0)])
    @test IS.is_convex(pld_convex)

    # Concave: slopes decreasing (2.0, 1.0)
    pld_concave =
        IS.PiecewiseLinearData([(x = 0.0, y = 0.0), (x = 1.0, y = 2.0), (x = 2.0, y = 3.0)])
    @test !IS.is_convex(pld_concave)

    # Linear (Colinear): slopes equal (1.0, 1.0)
    pld_linear =
        IS.PiecewiseLinearData([(x = 0.0, y = 0.0), (x = 1.0, y = 1.0), (x = 2.0, y = 2.0)])
    @test IS.is_convex(pld_linear)

    # Non-convex and Non-concave (Zigzag): slopes (1.0, 0.5, 1.5) -> decrease then increase
    # 0->1 (slope 1), 1->2 (slope 0.5), 2->3 (slope 1.5)
    pld_zigzag = IS.PiecewiseLinearData([
        (x = 0.0, y = 0.0),
        (x = 1.0, y = 1.0),
        (x = 2.0, y = 1.5),
        (x = 3.0, y = 3.0),
    ])
    @test !IS.is_convex(pld_zigzag)

    # PiecewiseStepData
    # Convex: y-coords increasing (1.0, 2.0)
    psd_convex = IS.PiecewiseStepData([0.0, 1.0, 2.0], [1.0, 2.0])
    @test IS.is_convex(psd_convex)

    # Concave: y-coords decreasing (2.0, 1.0)
    psd_concave = IS.PiecewiseStepData([0.0, 1.0, 2.0], [2.0, 1.0])
    @test !IS.is_convex(psd_concave)

    # Linear (Colinear): y-coords equal (1.0, 1.0)
    psd_linear = IS.PiecewiseStepData([0.0, 1.0, 2.0], [1.0, 1.0])
    @test IS.is_convex(psd_linear)

    # Non-convex and Non-concave (Zigzag): 1.0, 0.5, 1.5
    psd_zigzag = IS.PiecewiseStepData([0.0, 1.0, 2.0, 3.0], [1.0, 0.5, 1.5])
    @test !IS.is_convex(psd_zigzag)

    # Test ValueCurve types

    # LinearCurve (InputOutputCurve{LinearFunctionData})
    linear_curve = IS.InputOutputCurve(IS.LinearFunctionData(5.0, 1.0))
    @test IS.is_convex(linear_curve)

    # QuadraticCurve (InputOutputCurve{QuadraticFunctionData})
    quad_curve_convex = IS.InputOutputCurve(IS.QuadraticFunctionData(2.0, 3.0, 4.0))
    @test IS.is_convex(quad_curve_convex)

    quad_curve_concave = IS.InputOutputCurve(IS.QuadraticFunctionData(-2.0, 3.0, 4.0))
    @test !IS.is_convex(quad_curve_concave)

    # PiecewisePointCurve (InputOutputCurve{PiecewiseLinearData})
    pwp_curve_convex = IS.InputOutputCurve(
        IS.PiecewiseLinearData([
            (x = 0.0, y = 0.0),
            (x = 1.0, y = 1.0),
            (x = 2.0, y = 3.0),
        ]),
    )
    @test IS.is_convex(pwp_curve_convex)

    pwp_curve_concave = IS.InputOutputCurve(
        IS.PiecewiseLinearData([
            (x = 0.0, y = 0.0),
            (x = 1.0, y = 2.0),
            (x = 2.0, y = 3.0),
        ]),
    )
    @test !IS.is_convex(pwp_curve_concave)

    # PiecewiseIncrementalCurve (IncrementalCurve{PiecewiseStepData})
    pwi_curve_convex = IS.IncrementalCurve(
        IS.PiecewiseStepData([0.0, 1.0, 2.0], [1.0, 2.0]),
        0.0,
        0.0,
    )
    @test IS.is_convex(pwi_curve_convex)

    pwi_curve_concave = IS.IncrementalCurve(
        IS.PiecewiseStepData([0.0, 1.0, 2.0], [2.0, 1.0]),
        0.0,
        0.0,
    )
    @test !IS.is_convex(pwi_curve_concave)

    # PiecewiseAverageCurve (AverageRateCurve{PiecewiseStepData})
    pwa_curve_convex = IS.AverageRateCurve(
        IS.PiecewiseStepData([0.0, 1.0, 2.0], [1.0, 2.0]),
        0.0,
        0.0,
    )
    @test IS.is_convex(pwa_curve_convex)

    pwa_curve_concave = IS.AverageRateCurve(
        IS.PiecewiseStepData([0.0, 1.0, 2.0], [2.0, 1.0]),
        0.0,
        0.0,
    )
    @test !IS.is_convex(pwa_curve_concave)

    # Test is_concave
    # PiecewiseLinearData
    concave_pld =
        IS.PiecewiseLinearData([(x = 0.0, y = 0.0), (x = 1.0, y = 2.0), (x = 2.0, y = 3.0)])
    non_concave_pld =
        IS.PiecewiseLinearData([(x = 0.0, y = 0.0), (x = 1.0, y = 1.0), (x = 2.0, y = 3.0)])

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

    # PiecewiseIncrementalCurve (IncrementalCurve{PiecewiseStepData})
    concave_pic = IS.PiecewiseIncrementalCurve(0.0, [0.0, 1.0, 2.0], [2.0, 1.0])
    non_concave_pic = IS.PiecewiseIncrementalCurve(0.0, [0.0, 1.0, 2.0], [0.9, 1.0])

    @test IS.is_concave(concave_pic)
    @test !IS.is_concave(non_concave_pic)

    @test IS.is_concave(IS.CostCurve(concave_pic))
    @test !IS.is_concave(IS.CostCurve(non_concave_pic))
end

@testset "Test Data Quality Checks" begin
    # Test valid data returns true
    valid_pld = IS.PiecewiseLinearData([
        (x = 0.0, y = 0.0),
        (x = 1.0, y = 10.0),
        (x = 2.0, y = 25.0),
    ])
    @test IS.is_valid_data(valid_pld) == true

    # Use NullLogger to suppress expected error logs from validation tests
    Logging.with_logger(Logging.NullLogger()) do
        # Test negative slopes returns false
        negative_slope_pld = IS.PiecewiseLinearData([
            (x = 0.0, y = 10.0),
            (x = 1.0, y = 5.0),   # slope = -5
            (x = 2.0, y = 15.0),
        ])
        @test IS.is_valid_data(negative_slope_pld) == false

        # Test negative costs (y-values) returns false
        negative_cost_pld = IS.PiecewiseLinearData([
            (x = 0.0, y = -1e7),  # Very negative cost
            (x = 1.0, y = 10.0),
            (x = 2.0, y = 25.0),
        ])
        @test IS.is_valid_data(negative_cost_pld) == false

        # Test excessive slopes returns false
        excessive_slope_pld = IS.PiecewiseLinearData([
            (x = 0.0, y = 0.0),
            (x = 1.0, y = 1e9),   # slope = 1e9 > 1e8
            (x = 2.0, y = 2e9),
        ])
        @test IS.is_valid_data(excessive_slope_pld) == false

        # Test excessive magnitudes returns false
        excessive_magnitude_pld = IS.PiecewiseLinearData([
            (x = 0.0, y = 0.0),
            (x = 1.0, y = 1e11),  # > 1e10
            (x = 2.0, y = 1.1e11),
        ])
        @test IS.is_valid_data(excessive_magnitude_pld) == false

        # Test PiecewiseStepData with negative rates returns false
        negative_rate_psd = IS.PiecewiseStepData([0.0, 1.0, 2.0], [-5.0, 10.0])
        @test IS.is_valid_data(negative_rate_psd) == false

        # Test LinearFunctionData with negative slope
        negative_slope_lfd = IS.LinearFunctionData(-5.0, 10.0)
        @test IS.is_valid_data(negative_slope_lfd) == false

        # Test QuadraticFunctionData with negative proportional term
        negative_proportional_qfd = IS.QuadraticFunctionData(0.1, -5.0, 10.0)
        @test IS.is_valid_data(negative_proportional_qfd) == false

        # Test ValueCurve wrapper with invalid data
        invalid_ioc = IS.InputOutputCurve(IS.PiecewiseLinearData([
            (x = 0.0, y = 10.0),
            (x = 1.0, y = 5.0),
            (x = 2.0, y = 15.0),
        ]))
        @test IS.is_valid_data(invalid_ioc) == false
    end

    # Test valid LinearFunctionData
    valid_lfd = IS.LinearFunctionData(5.0, 10.0)
    @test IS.is_valid_data(valid_lfd) == true

    # Test valid QuadraticFunctionData
    valid_qfd = IS.QuadraticFunctionData(0.1, 5.0, 10.0)
    @test IS.is_valid_data(valid_qfd) == true

    # Test ValueCurve wrappers
    valid_ioc = IS.InputOutputCurve(valid_pld)
    @test IS.is_valid_data(valid_ioc) == true

    # Test AverageRateCurve validates via InputOutputCurve conversion
    # This ensures the actual slopes are checked, not just the average rates
    valid_arc_psd = IS.PiecewiseStepData([0.0, 1.0, 2.0], [1.0, 2.0])  # Valid average rates
    valid_arc = IS.AverageRateCurve(valid_arc_psd, 0.0)
    @test IS.is_valid_data(valid_arc) == true
end
