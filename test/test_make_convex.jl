using Test
using InfrastructureSystems
const IS = InfrastructureSystems

@testset "Convexity Checks and make_convex Tests" begin
    include("test_convexity_checks.jl")
    include("test_merge_colinear.jl")

    @testset "Test make_convex for InputOutputCurve{LinearFunctionData}" begin
        # LinearCurve - always convex
        lfd = IS.LinearFunctionData(5.0, 1.0)
        lc = IS.InputOutputCurve(lfd)
        result = IS.make_convex(lc)
        @test IS.is_convex(result)
        @test result === lc  # Should return same object
    end

    @testset "Test make_convex for InputOutputCurve{QuadraticFunctionData}" begin
        # Convex quadratic (a > 0) - unchanged
        qfd_convex = IS.QuadraticFunctionData(2.0, 3.0, 4.0)
        qc_convex = IS.InputOutputCurve(qfd_convex)
        result = IS.make_convex(qc_convex)
        @test IS.is_convex(result)
        @test result === qc_convex

        # Concave quadratic (a < 0) - projects to linear
        qfd_concave = IS.QuadraticFunctionData(-2.0, 3.0, 4.0)
        qc_concave = IS.InputOutputCurve(qfd_concave)
        result = IS.make_convex(qc_concave)
        @test IS.is_convex(result)
        @test result isa IS.InputOutputCurve{IS.LinearFunctionData}
        fd = IS.get_function_data(result)
        @test IS.get_proportional_term(fd) == 3.0
        @test IS.get_constant_term(fd) == 4.0
    end

    @testset "Test make_convex for InputOutputCurve{PiecewiseLinearData}" begin
        # Convex (non-decreasing slopes) - unchanged
        pld_convex = IS.PiecewiseLinearData([(x=0.0, y=0.0), (x=1.0, y=1.0), (x=2.0, y=3.0)])
        ppc_convex = IS.InputOutputCurve(pld_convex)
        result = IS.make_convex(ppc_convex)
        @test IS.is_convex(result)
        @test result === ppc_convex

        # Concave (decreasing slopes) - apply isotonic regression
        pld_concave = IS.PiecewiseLinearData([(x=0.0, y=0.0), (x=1.0, y=2.0), (x=2.0, y=3.0)])
        ppc_concave = IS.InputOutputCurve(pld_concave)
        result = IS.make_convex(ppc_concave)
        @test IS.is_convex(result)
        # With merge_colinear=true (default), equal slopes get merged into single segment
        # With merge_colinear=false, slopes should be equal (both 1.5)
        result_no_merge = IS.make_convex(ppc_concave; merge_colinear = false)
        slopes = IS.get_slopes(IS.get_function_data(result_no_merge))
        @test slopes[1] ≤ slopes[2]
    end

    @testset "Test make_convex for IncrementalCurve{PiecewiseStepData}" begin
        # Convex (non-decreasing y-coords) - unchanged
        psd_convex = IS.PiecewiseStepData([0.0, 1.0, 2.0], [1.0, 2.0])
        pic_convex = IS.IncrementalCurve(psd_convex, 0.0)
        result = IS.make_convex(pic_convex)
        @test IS.is_convex(result)
        @test result === pic_convex

        # Concave (decreasing y-coords) - apply isotonic regression
        psd_concave = IS.PiecewiseStepData([0.0, 1.0, 2.0, 3.0], [3.0, 2.0, 1.0])
        pic_concave = IS.IncrementalCurve(psd_concave, 0.0)
        result = IS.make_convex(pic_concave)
        @test IS.is_convex(result)
        # With merge_colinear=true (default), equal y-values get merged
        # With merge_colinear=false, y-coords should be equal (all 2.0)
        result_no_merge = IS.make_convex(pic_concave; merge_colinear = false)
        @test IS.get_y_coords(IS.get_function_data(result_no_merge)) ≈ [2.0, 2.0, 2.0]
    end

    @testset "Test make_convex for AverageRateCurve{PiecewiseStepData}" begin
        # AverageRateCurve{PiecewiseStepData}
        psd = IS.PiecewiseStepData([0.0, 1.0, 2.0], [1.0, 2.0])
        arc_psd = IS.AverageRateCurve(psd, 0.0)
        result = IS.make_convex(arc_psd)
        @test IS.is_convex(result)
    end

    @testset "Test is_convex for ValueCurves with integration" begin
        # Test that IncrementalCurve performs integration for convexity check
        psd = IS.PiecewiseStepData([0.0, 1.0, 2.0], [3.0, 5.0])
        inc = IS.IncrementalCurve(psd, 10.0, 0.0)
        @test IS.is_convex(inc)

        # Verify integration happens correctly
        ioc = IS.InputOutputCurve(inc)
        pld = IS.get_function_data(ioc)
        points = IS.get_points(pld)
        @test points[1].y == 10.0
        @test points[2].y ≈ 13.0  # 10 + 3*1
        @test points[3].y ≈ 18.0  # 13 + 5*1

        # Test concave incremental curve
        psd_concave = IS.PiecewiseStepData([0.0, 1.0, 2.0], [5.0, 3.0])
        inc_concave = IS.IncrementalCurve(psd_concave, 0.0, 0.0)
        @test !IS.is_convex(inc_concave)
    end

    @testset "Test make_convex idempotency" begin
        # make_convex(make_convex(x)) should equal make_convex(x)
        psd = IS.PiecewiseStepData([0.0, 1.0, 2.0], [3.0, 1.0])  # concave
        ic = IS.IncrementalCurve(psd, 0.0)
        convex_once = IS.make_convex(ic)
        convex_twice = IS.make_convex(convex_once)

        @test IS.get_y_coords(IS.get_function_data(convex_once)) ==
              IS.get_y_coords(IS.get_function_data(convex_twice))
        @test IS.is_convex(convex_once)
        @test IS.is_convex(convex_twice)
        @test convex_twice === convex_once  # Should return same object
    end

    @testset "Test make_convex anchor options for PiecewiseLinearData" begin
        # Concave curve with slopes [2.0, 1.0]
        pld = IS.PiecewiseLinearData([(x=0.0, y=0.0), (x=1.0, y=2.0), (x=2.0, y=3.0)])
        ioc = IS.InputOutputCurve(pld)

        # Test anchor=:first (default) - preserves first point
        result_first = IS.make_convex(ioc; anchor=:first)
        points_first = IS.get_points(IS.get_function_data(result_first))
        @test points_first[1] == (x=0.0, y=0.0)  # First point preserved

        # Test anchor=:last - preserves last point
        result_last = IS.make_convex(ioc; anchor=:last)
        points_last = IS.get_points(IS.get_function_data(result_last))
        @test points_last[end] == (x=2.0, y=3.0)  # Last point preserved
    end
end
