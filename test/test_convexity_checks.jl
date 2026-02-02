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
