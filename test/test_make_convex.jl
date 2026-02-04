@testset "increasing_curve_convex_approximation Tests" begin
    @testset "Test increasing_curve_convex_approximation for InputOutputCurve{PiecewiseLinearData}" begin
        # Convex (non-decreasing slopes) - unchanged
        pld_convex = IS.PiecewiseLinearData([
            (x = 0.0, y = 0.0),
            (x = 1.0, y = 1.0),
            (x = 2.0, y = 3.0),
        ])
        ppc_convex = IS.InputOutputCurve(pld_convex)
        result = IS.increasing_curve_convex_approximation(ppc_convex)
        @test IS.is_convex(result)
        @test result === ppc_convex

        # Concave (decreasing slopes) - apply isotonic regression
        pld_concave = IS.PiecewiseLinearData([
            (x = 0.0, y = 0.0),
            (x = 1.0, y = 2.0),
            (x = 2.0, y = 3.0),
        ])
        ppc_concave = IS.InputOutputCurve(pld_concave)
        result = IS.increasing_curve_convex_approximation(ppc_concave)
        @test IS.is_convex(result)
        # With merge_colinear=true (default), equal slopes get merged into single segment
        # With merge_colinear=false, slopes should be equal (both 1.5)
        result_no_merge =
            IS.increasing_curve_convex_approximation(ppc_concave; merge_colinear = false)
        slopes = IS.get_slopes(IS.get_function_data(result_no_merge))
        @test slopes[1] ≤ slopes[2]
    end

    @testset "Test increasing_curve_convex_approximation for IncrementalCurve{PiecewiseStepData}" begin
        # Convex (non-decreasing y-coords) - unchanged
        psd_convex = IS.PiecewiseStepData([0.0, 1.0, 2.0], [1.0, 2.0])
        pic_convex = IS.IncrementalCurve(psd_convex, 0.0)
        result = IS.increasing_curve_convex_approximation(pic_convex)
        @test IS.is_convex(result)
        @test result === pic_convex

        # Concave (decreasing y-coords) - apply isotonic regression
        psd_concave = IS.PiecewiseStepData([0.0, 1.0, 2.0, 3.0], [3.0, 2.0, 1.0])
        pic_concave = IS.IncrementalCurve(psd_concave, 0.0)
        result = IS.increasing_curve_convex_approximation(pic_concave)
        @test IS.is_convex(result)
        # With merge_colinear=true (default), equal y-values get merged
        # With merge_colinear=false, y-coords should be equal (all 2.0)
        result_no_merge =
            IS.increasing_curve_convex_approximation(pic_concave; merge_colinear = false)
        @test IS.get_y_coords(IS.get_function_data(result_no_merge)) ≈ [2.0, 2.0, 2.0]
    end

    @testset "Test increasing_curve_convex_approximation for AverageRateCurve{PiecewiseStepData}" begin
        # AverageRateCurve{PiecewiseStepData} - increasing
        psd = IS.PiecewiseStepData([0.0, 1.0, 2.0], [1.0, 2.0])
        arc_psd = IS.AverageRateCurve(psd, 0.0)
        result = IS.increasing_curve_convex_approximation(arc_psd)
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

        # Test increasing_curve_convex_approximation on concave curve
        result = IS.increasing_curve_convex_approximation(inc_concave)
        @test IS.is_convex(result)
    end

    @testset "Test increasing_curve_convex_approximation idempotency" begin
        # increasing_curve_convex_approximation(increasing_curve_convex_approximation(x)) should equal increasing_curve_convex_approximation(x)
        psd = IS.PiecewiseStepData([0.0, 1.0, 2.0], [3.0, 1.0])  # concave
        ic = IS.IncrementalCurve(psd, 0.0)
        convex_once = IS.increasing_curve_convex_approximation(ic)
        convex_twice = IS.increasing_curve_convex_approximation(convex_once)

        @test IS.get_y_coords(IS.get_function_data(convex_once)) ==
              IS.get_y_coords(IS.get_function_data(convex_twice))
        @test IS.is_convex(convex_once)
        @test IS.is_convex(convex_twice)
        @test convex_twice === convex_once  # Should return same object
    end

    @testset "Test increasing_curve_convex_approximation anchor options for PiecewiseLinearData" begin
        # Concave curve with slopes [2.0, 1.0]
        pld = IS.PiecewiseLinearData([
            (x = 0.0, y = 0.0),
            (x = 1.0, y = 2.0),
            (x = 2.0, y = 3.0),
        ])
        ioc = IS.InputOutputCurve(pld)

        # Test anchor=:first (default) - preserves first point
        result_first = IS.increasing_curve_convex_approximation(ioc; anchor = :first)
        points_first = IS.get_points(IS.get_function_data(result_first))
        @test points_first[1] == (x = 0.0, y = 0.0)  # First point preserved

        # Test anchor=:last - preserves last point
        result_last = IS.increasing_curve_convex_approximation(ioc; anchor = :last)
        points_last = IS.get_points(IS.get_function_data(result_last))
        @test points_last[end] == (x = 2.0, y = 3.0)  # Last point preserved
    end

    @testset "Test increasing_curve_convex_approximation rejects non-strictly-increasing curves" begin
        # Curve with a negative slope segment (not strictly increasing)
        pld_neg = IS.PiecewiseLinearData([
            (x = 0.0, y = 10.0),
            (x = 1.0, y = 5.0),   # slope = -5 (decreasing)
            (x = 2.0, y = 8.0),
        ])
        ioc_neg = IS.InputOutputCurve(pld_neg)
        @test !IS.is_strictly_increasing(ioc_neg)

        # Should return nothing and log error
        Logging.with_logger(Logging.NullLogger()) do
            result = IS.increasing_curve_convex_approximation(ioc_neg)
            @test result === nothing
        end

        # Same test with IncrementalCurve
        psd_neg = IS.PiecewiseStepData([0.0, 1.0, 2.0], [-1.0, 2.0])
        pic_neg = IS.IncrementalCurve(psd_neg, 0.0)
        @test !IS.is_strictly_increasing(pic_neg)

        Logging.with_logger(Logging.NullLogger()) do
            result = IS.increasing_curve_convex_approximation(pic_neg)
            @test result === nothing
        end
    end

    @testset "Test increasing_curve_convex_approximation generator_name in logs" begin
        # Non-convex curve that will produce a warning
        pld = IS.PiecewiseLinearData([
            (x = 0.0, y = 0.0),
            (x = 1.0, y = 10.0),  # slope = 10
            (x = 2.0, y = 15.0),  # slope = 5 (non-convex)
        ])
        ioc = IS.InputOutputCurve(pld)

        # Capture logs and verify generator name appears
        Test.@test_logs(
            (:warn, r".*for generator TestGen123.*"),
            IS.increasing_curve_convex_approximation(ioc; generator_name = "TestGen123"),
        )

        # Without generator_name, message should not include "for generator"
        Test.@test_logs(
            (:warn, r"^Transformed non-convex InputOutputCurve to convex approximation$"),
            IS.increasing_curve_convex_approximation(ioc),
        )
    end
end
