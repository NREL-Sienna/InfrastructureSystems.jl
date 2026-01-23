@testset "Test Convexity Checks" begin
    # LinearFunctionData
    lfd = IS.LinearFunctionData(5.0, 1.0)
    @test IS.is_convex(lfd)
    @test !IS.is_concave(lfd)

    # QuadraticFunctionData
    qfd_convex = IS.QuadraticFunctionData(2.0, 3.0, 4.0)  # a > 0
    @test IS.is_convex(qfd_convex)
    @test !IS.is_concave(qfd_convex)

    qfd_concave = IS.QuadraticFunctionData(-2.0, 3.0, 4.0)  # a < 0
    @test !IS.is_convex(qfd_concave)
    @test IS.is_concave(qfd_concave)

    qfd_linear = IS.QuadraticFunctionData(0.0, 3.0, 4.0)  # a = 0
    @test IS.is_convex(qfd_linear)
    @test !IS.is_concave(qfd_linear)

    # PiecewiseLinearData
    # Convex: slopes increasing (1.0, 2.0)
    pld_convex = IS.PiecewiseLinearData([(x=0.0, y=0.0), (x=1.0, y=1.0), (x=2.0, y=3.0)])
    @test IS.is_convex(pld_convex)
    @test !IS.is_concave(pld_convex)

    # Concave: slopes decreasing (2.0, 1.0)
    pld_concave = IS.PiecewiseLinearData([(x=0.0, y=0.0), (x=1.0, y=2.0), (x=2.0, y=3.0)])
    @test !IS.is_convex(pld_concave)
    @test IS.is_concave(pld_concave)

    # Linear (Colinear): slopes equal (1.0, 1.0)
    pld_linear = IS.PiecewiseLinearData([(x=0.0, y=0.0), (x=1.0, y=1.0), (x=2.0, y=2.0)])
    @test IS.is_convex(pld_linear)
    @test !IS.is_concave(pld_linear)

    # Non-convex and Non-concave (Zigzag): slopes (1.0, 0.5, 1.5) -> decrease then increase
    # 0->1 (slope 1), 1->2 (slope 0.5), 2->3 (slope 1.5)
    pld_zigzag = IS.PiecewiseLinearData([(x=0.0, y=0.0), (x=1.0, y=1.0), (x=2.0, y=1.5), (x=3.0, y=3.0)])
    @test !IS.is_convex(pld_zigzag)
    @test !IS.is_concave(pld_zigzag)

    # PiecewiseStepData
    # Convex: y-coords increasing (1.0, 2.0)
    psd_convex = IS.PiecewiseStepData([0.0, 1.0, 2.0], [1.0, 2.0])
    @test IS.is_convex(psd_convex)
    @test !IS.is_concave(psd_convex)

    # Concave: y-coords decreasing (2.0, 1.0)
    psd_concave = IS.PiecewiseStepData([0.0, 1.0, 2.0], [2.0, 1.0])
    @test !IS.is_convex(psd_concave)
    @test IS.is_concave(psd_concave)

    # Linear (Colinear): y-coords equal (1.0, 1.0)
    psd_linear = IS.PiecewiseStepData([0.0, 1.0, 2.0], [1.0, 1.0])
    @test IS.is_convex(psd_linear)
    @test !IS.is_concave(psd_linear)

    # Non-convex and Non-concave (Zigzag): 1.0, 0.5, 1.5
    psd_zigzag = IS.PiecewiseStepData([0.0, 1.0, 2.0, 3.0], [1.0, 0.5, 1.5])
    @test !IS.is_convex(psd_zigzag)
    @test !IS.is_concave(psd_zigzag)
end
