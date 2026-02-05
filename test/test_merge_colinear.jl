@testset "Merge Colinear Segments Tests" begin
    @testset "merge_colinear_segments for PiecewisePointCurve" begin
        # Test 1: Fully colinear curve (3 points on a line with slope 1)
        # Points: (0,0), (1,1), (2,2) -> slopes: [1.0, 1.0]
        # Should reduce to 2 points: (0,0), (2,2)
        pld_colinear = IS.PiecewiseLinearData([
            (x = 0.0, y = 0.0),
            (x = 1.0, y = 1.0),
            (x = 2.0, y = 2.0),
        ])
        curve_colinear = IS.InputOutputCurve(pld_colinear)
        result = IS.merge_colinear_segments(curve_colinear)

        @test length(IS.get_points(IS.get_function_data(result))) == 2
        points = IS.get_points(IS.get_function_data(result))
        @test points[1] == (x = 0.0, y = 0.0)
        @test points[2] == (x = 2.0, y = 2.0)

        # Test 2: Multiple colinear groups
        # Points: (0,0), (1,1), (2,2), (3,5), (4,8), (5,11) 
        # Slopes: [1.0, 1.0, 3.0, 3.0, 3.0]
        # Should reduce to: (0,0), (2,2), (5,11)
        pld_multi = IS.PiecewiseLinearData([
            (x = 0.0, y = 0.0),
            (x = 1.0, y = 1.0),
            (x = 2.0, y = 2.0),
            (x = 3.0, y = 5.0),
            (x = 4.0, y = 8.0),
            (x = 5.0, y = 11.0),
        ])
        curve_multi = IS.InputOutputCurve(pld_multi)
        result_multi = IS.merge_colinear_segments(curve_multi)

        @test length(IS.get_points(IS.get_function_data(result_multi))) == 3
        points_multi = IS.get_points(IS.get_function_data(result_multi))
        @test points_multi[1] == (x = 0.0, y = 0.0)
        @test points_multi[2] == (x = 2.0, y = 2.0)
        @test points_multi[3] == (x = 5.0, y = 11.0)

        # Test 3: No colinear segments (slopes: 1.0, 2.0, 3.0)
        pld_no_colinear = IS.PiecewiseLinearData([
            (x = 0.0, y = 0.0),
            (x = 1.0, y = 1.0),
            (x = 2.0, y = 3.0),
            (x = 3.0, y = 6.0),
        ])
        curve_no_colinear = IS.InputOutputCurve(pld_no_colinear)
        result_no_colinear = IS.merge_colinear_segments(curve_no_colinear)

        # Should be unchanged (returned as-is)
        @test result_no_colinear === curve_no_colinear

        # Test 4: Only 2 points (single segment, nothing to merge)
        pld_two_points = IS.PiecewiseLinearData([
            (x = 0.0, y = 0.0),
            (x = 1.0, y = 1.0),
        ])
        curve_two_points = IS.InputOutputCurve(pld_two_points)
        result_two = IS.merge_colinear_segments(curve_two_points)

        @test result_two === curve_two_points

        # Test 5: Preserves endpoints exactly with near-colinear tolerance
        # Slopes: [1.0, 1.0 + 1e-12, 1.0] -> all within tolerance
        pld_near_colinear = IS.PiecewiseLinearData([
            (x = 0.0, y = 0.0),
            (x = 1.0, y = 1.0),
            (x = 2.0, y = 2.0 + 1e-12),
            (x = 3.0, y = 3.0 + 1e-12),
        ])
        curve_near = IS.InputOutputCurve(pld_near_colinear)
        result_near = IS.merge_colinear_segments(curve_near)

        points_near = IS.get_points(IS.get_function_data(result_near))
        @test length(points_near) == 2
        @test points_near[1] == (x = 0.0, y = 0.0)
        @test points_near[2].x == 3.0  # Endpoint x preserved

        # Test 6: Custom tolerance - larger epsilon should merge more
        pld_custom_tol = IS.PiecewiseLinearData([
            (x = 0.0, y = 0.0),
            (x = 1.0, y = 1.0),  # slope 1.0
            (x = 2.0, y = 2.1),  # slope 1.1
            (x = 3.0, y = 3.2),  # slope 1.1
        ])
        curve_custom = IS.InputOutputCurve(pld_custom_tol)

        # With small tolerance, should merge only the equal slopes (1.1, 1.1)
        # Slopes [1.0, 1.1, 1.1] -> second and third are equal, so merge those segments
        result_small_tol = IS.merge_colinear_segments(curve_custom; ε = 1e-10)
        points_small = IS.get_points(IS.get_function_data(result_small_tol))
        @test length(points_small) == 3  # (0,0), (1,1), (3,3.2)
        @test points_small[1] == (x = 0.0, y = 0.0)
        @test points_small[2] == (x = 1.0, y = 1.0)
        @test points_small[3] == (x = 3.0, y = 3.2)

        # With larger tolerance (0.2), should merge all (1.0 and 1.1 are within 0.2)
        result_large_tol = IS.merge_colinear_segments(curve_custom; ε = 0.2)
        @test length(IS.get_points(IS.get_function_data(result_large_tol))) == 2

        # Test 7: Input with input_at_zero preserves it
        curve_with_iaz = IS.InputOutputCurve(pld_colinear, 0.5)
        result_iaz = IS.merge_colinear_segments(curve_with_iaz)
        @test IS.get_input_at_zero(result_iaz) == 0.5
    end

    @testset "merge_colinear_segments for PiecewiseIncrementalCurve" begin
        # Test 1: Colinear steps (same slope values)
        # x: [0, 1, 2, 3], y: [2.0, 2.0, 2.0] -> should merge to [0, 3], [2.0]
        psd_colinear = IS.PiecewiseStepData([0.0, 1.0, 2.0, 3.0], [2.0, 2.0, 2.0])
        ic_colinear = IS.IncrementalCurve(psd_colinear, 0.0)
        result = IS.merge_colinear_segments(ic_colinear)

        fd_result = IS.get_function_data(result)
        @test IS.get_x_coords(fd_result) == [0.0, 3.0]
        @test IS.get_y_coords(fd_result) == [2.0]

        # Test 2: Multiple colinear groups
        # x: [0, 1, 2, 3, 4], y: [1.0, 1.0, 3.0, 3.0]
        # Should reduce to: x: [0, 2, 4], y: [1.0, 3.0]
        psd_multi = IS.PiecewiseStepData([0.0, 1.0, 2.0, 3.0, 4.0], [1.0, 1.0, 3.0, 3.0])
        ic_multi = IS.IncrementalCurve(psd_multi, 5.0)
        result_multi = IS.merge_colinear_segments(ic_multi)

        fd_multi = IS.get_function_data(result_multi)
        @test IS.get_x_coords(fd_multi) == [0.0, 2.0, 4.0]
        @test IS.get_y_coords(fd_multi) == [1.0, 3.0]
        @test IS.get_initial_input(result_multi) == 5.0

        # Test 3: No colinear segments
        psd_no_colinear = IS.PiecewiseStepData([0.0, 1.0, 2.0, 3.0], [1.0, 2.0, 3.0])
        ic_no_colinear = IS.IncrementalCurve(psd_no_colinear, 0.0)
        result_no_colinear = IS.merge_colinear_segments(ic_no_colinear)

        @test result_no_colinear === ic_no_colinear

        # Test 4: Single segment - nothing to merge
        psd_single = IS.PiecewiseStepData([0.0, 1.0], [2.0])
        ic_single = IS.IncrementalCurve(psd_single, 0.0)
        result_single = IS.merge_colinear_segments(ic_single)

        @test result_single === ic_single

        # Test 5: Preserves input_at_zero
        ic_with_iaz = IS.IncrementalCurve(psd_colinear, 10.0, 0.5)
        result_iaz = IS.merge_colinear_segments(ic_with_iaz)
        @test IS.get_input_at_zero(result_iaz) == 0.5
        @test IS.get_initial_input(result_iaz) == 10.0
    end

    @testset "merge_colinear_segments for PiecewiseAverageCurve" begin
        # Test 1: Colinear steps (same rate values)
        psd_colinear = IS.PiecewiseStepData([0.0, 1.0, 2.0, 3.0], [2.0, 2.0, 2.0])
        ac_colinear = IS.AverageRateCurve(psd_colinear, 0.0)
        result = IS.merge_colinear_segments(ac_colinear)

        fd_result = IS.get_function_data(result)
        @test IS.get_x_coords(fd_result) == [0.0, 3.0]
        @test IS.get_y_coords(fd_result) == [2.0]

        # Test 2: Multiple colinear groups
        psd_multi = IS.PiecewiseStepData([0.0, 1.0, 2.0, 3.0, 4.0], [1.0, 1.0, 3.0, 3.0])
        ac_multi = IS.AverageRateCurve(psd_multi, 5.0)
        result_multi = IS.merge_colinear_segments(ac_multi)

        fd_multi = IS.get_function_data(result_multi)
        @test IS.get_x_coords(fd_multi) == [0.0, 2.0, 4.0]
        @test IS.get_y_coords(fd_multi) == [1.0, 3.0]
        @test IS.get_initial_input(result_multi) == 5.0

        # Test 3: No colinear segments - unchanged
        psd_no_colinear = IS.PiecewiseStepData([0.0, 1.0, 2.0, 3.0], [1.0, 2.0, 3.0])
        ac_no_colinear = IS.AverageRateCurve(psd_no_colinear, 0.0)
        result_no_colinear = IS.merge_colinear_segments(ac_no_colinear)

        @test result_no_colinear === ac_no_colinear

        # Test 4: Preserves input_at_zero
        ac_with_iaz = IS.AverageRateCurve(psd_colinear, 10.0, 0.5)
        result_iaz = IS.merge_colinear_segments(ac_with_iaz)
        @test IS.get_input_at_zero(result_iaz) == 0.5
        @test IS.get_initial_input(result_iaz) == 10.0
    end

    @testset "Edge cases and numerical stability" begin
        # Test with very small segment lengths
        pld_small = IS.PiecewiseLinearData([
            (x = 0.0, y = 0.0),
            (x = 1e-8, y = 1e-8),
            (x = 2e-8, y = 2e-8),
            (x = 1.0, y = 1.0),
        ])
        curve_small = IS.InputOutputCurve(pld_small)
        result_small = IS.merge_colinear_segments(curve_small)
        # All segments have slope 1.0, should merge to 2 points
        @test length(IS.get_points(IS.get_function_data(result_small))) == 2

        # Test with large values
        pld_large = IS.PiecewiseLinearData([
            (x = 0.0, y = 0.0),
            (x = 1e6, y = 1e6),
            (x = 2e6, y = 2e6),
        ])
        curve_large = IS.InputOutputCurve(pld_large)
        result_large = IS.merge_colinear_segments(curve_large)
        @test length(IS.get_points(IS.get_function_data(result_large))) == 2

        # Test alternating colinear groups
        # slopes: [1, 1, 2, 2, 1, 1]
        pld_alt = IS.PiecewiseLinearData([
            (x = 0.0, y = 0.0),
            (x = 1.0, y = 1.0),
            (x = 2.0, y = 2.0),
            (x = 3.0, y = 4.0),
            (x = 4.0, y = 6.0),
            (x = 5.0, y = 7.0),
            (x = 6.0, y = 8.0),
        ])
        curve_alt = IS.InputOutputCurve(pld_alt)
        result_alt = IS.merge_colinear_segments(curve_alt)
        # Should have 4 points: (0,0), (2,2), (4,6), (6,8)
        @test length(IS.get_points(IS.get_function_data(result_alt))) == 4
    end

    @testset "Integration with increasing_curve_convex_approximation" begin
        # Test that colinear segments are cleaned up before convexification
        # Create a curve with colinear segments that appears non-convex due to segmentation
        # but is actually convex after cleanup

        # Slopes: [1, 1, 2, 2] - convex (non-decreasing) after merge
        pld_colinear_convex = IS.PiecewiseLinearData([
            (x = 0.0, y = 0.0),
            (x = 1.0, y = 1.0),
            (x = 2.0, y = 2.0),
            (x = 3.0, y = 4.0),
            (x = 4.0, y = 6.0),
        ])
        curve = IS.InputOutputCurve(pld_colinear_convex)

        # Make convex with merge_colinear=true (default)
        result = IS.increasing_curve_convex_approximation(curve)
        @test IS.is_convex(result)

        # The result should have fewer points due to colinearity cleanup
        @test length(IS.get_points(IS.get_function_data(result))) == 3

        # Test with merge_colinear=false to verify the option works
        result_no_merge =
            IS.increasing_curve_convex_approximation(curve; merge_colinear = false)
        @test IS.is_convex(result_no_merge)
        # Without merge, convexity check passes since slopes are non-decreasing
        # and original curve is returned
        @test result_no_merge === curve

        # Test IncrementalCurve integration
        psd_colinear = IS.PiecewiseStepData([0.0, 1.0, 2.0, 3.0], [1.0, 1.0, 2.0])
        ic = IS.IncrementalCurve(psd_colinear, 0.0)
        result_ic = IS.increasing_curve_convex_approximation(ic)
        @test IS.is_convex(result_ic)

        # Test AverageRateCurve integration
        psd_avg = IS.PiecewiseStepData([0.0, 1.0, 2.0, 3.0], [1.0, 1.0, 2.0])
        ac = IS.AverageRateCurve(psd_avg, 0.0)
        result_ac = IS.increasing_curve_convex_approximation(ac)
        @test IS.is_convex(result_ac)
    end

    @testset "Geometry preservation" begin
        # Verify that merging colinear segments preserves the geometric interpretation
        # A merged curve should evaluate to the same values at the kept points

        pld_colinear = IS.PiecewiseLinearData([
            (x = 0.0, y = 0.0),
            (x = 1.0, y = 2.0),
            (x = 2.0, y = 4.0),  # slope 2 throughout
            (x = 3.0, y = 6.0),
        ])
        curve = IS.InputOutputCurve(pld_colinear)
        result = IS.merge_colinear_segments(curve)

        # The merged curve should have 2 points
        points = IS.get_points(IS.get_function_data(result))
        @test points[1] == (x = 0.0, y = 0.0)
        @test points[2] == (x = 3.0, y = 6.0)

        # Evaluate at intermediate x values using the curve
        # At x=1.5, y should be 3.0 (linear interpolation)
        @test curve(1.5) == 3.0
        @test result(1.5) == 3.0
    end
end
