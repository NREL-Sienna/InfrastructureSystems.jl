using Test
using InfrastructureSystems
const IS = InfrastructureSystems

@testset "Convexity Checks and make_convex Tests" begin
    include("test_convexity_checks.jl")
    
    # Extract make_convex tests from test_function_data.jl
    @testset "Test make_convex for PiecewiseStepData" begin
        # Convex data (non-decreasing y-coordinates)
        psd_convex = IS.PiecewiseStepData([0.0, 1.0, 2.0, 3.0], [1.0, 2.0, 3.0])
        result = IS.make_convex(psd_convex)
        @test IS.is_convex(result)
        @test result === psd_convex  # Should return same object if already convex
        
        # Concave data (decreasing y-coordinates)
        psd_concave = IS.PiecewiseStepData([0.0, 1.0, 2.0, 3.0], [3.0, 2.0, 1.0])
        result = IS.make_convex(psd_concave)
        @test IS.is_convex(result)
        @test IS.get_y_coords(result) ≈ [2.0, 2.0, 2.0]  # PAVA should average
        
        # Mixed convexity
        psd_mixed = IS.PiecewiseStepData([0.0, 1.0, 2.0, 3.0], [1.0, 3.0, 2.0])
        result = IS.make_convex(psd_mixed)
        @test IS.is_convex(result)
    end
    
    @testset "Test make_convex for PiecewiseLinearData" begin
        # Convex (non-decreasing slopes)
        pld_convex = IS.PiecewiseLinearData([(x=0.0, y=0.0), (x=1.0, y=1.0), (x=2.0, y=3.0)])
        result = IS.make_convex(pld_convex)
        @test IS.is_convex(result)
        @test result === pld_convex
        
        # Concave (decreasing slopes)
        pld_concave = IS.PiecewiseLinearData([(x=0.0, y=0.0), (x=1.0, y=2.0), (x=2.0, y=3.0)])
        result = IS.make_convex(pld_concave)
        @test IS.is_convex(result)
        @test IS.get_slopes(result)[1] ≤ IS.get_slopes(result)[2]
    end
    
    @testset "Test make_convex for FunctionData types" begin
        # LinearFunctionData - always convex
        lfd = IS.LinearFunctionData(5.0, 1.0)
        result = IS.make_convex(lfd)
        @test IS.is_convex(result)
        @test result === lfd
        
        # QuadraticFunctionData - convex
        qfd_convex = IS.QuadraticFunctionData(2.0, 3.0, 4.0)
        result = IS.make_convex(qfd_convex)
        @test IS.is_convex(result)
        @test result === qfd_convex
        
        # QuadraticFunctionData - concave
        qfd_concave = IS.QuadraticFunctionData(-2.0, 3.0, 4.0)
        result = IS.make_convex(qfd_concave)
        @test IS.is_convex(result)
        @test typeof(result) == IS.LinearFunctionData
        @test IS.get_proportional_term(result) == 3.0
        @test IS.get_constant_term(result) == 4.0
    end
    
    @testset "Test make_convex for ValueCurves" begin
        # LinearCurve - always convex
        lfd = IS.LinearFunctionData(5.0, 1.0)
        lc = IS.LinearCurve(lfd)
        result = IS.make_convex(lc)
        @test IS.is_convex(result)
        @test result === lc
        
        # QuadraticCurve - convex
        qfd_convex = IS.QuadraticFunctionData(2.0, 3.0, 4.0)
        qc_convex = IS.QuadraticCurve(qfd_convex)
        result = IS.make_convex(qc_convex)
        @test IS.is_convex(result)
        
        # QuadraticCurve - concave
        qfd_concave = IS.QuadraticFunctionData(-2.0, 3.0, 4.0)
        qc_concave = IS.QuadraticCurve(qfd_concave)
        result = IS.make_convex(qc_concave)
        @test IS.is_convex(result)
        @test typeof(result) == IS.LinearCurve
        
        # PiecewisePointCurve - convex
        pld_convex = IS.PiecewiseLinearData([(x=0.0, y=0.0), (x=1.0, y=1.0), (x=2.0, y=3.0)])
        ppc_convex = IS.PiecewisePointCurve(pld_convex)
        result = IS.make_convex(ppc_convex)
        @test IS.is_convex(result)
        
        # PiecewiseIncrementalCurve
        psd_convex = IS.PiecewiseStepData([0.0, 1.0, 2.0], [1.0, 2.0])
        pic = IS.PiecewiseIncrementalCurve(psd_convex, 0.0)
        result = IS.make_convex(pic)
        @test IS.is_convex(result)
        
        # IncrementalCurve{LinearFunctionData}
        lfd_inc = IS.LinearFunctionData(2.0, 3.0)
        ic = IS.IncrementalCurve(lfd_inc, 0.0)
        result = IS.make_convex(ic)
        @test IS.is_convex(result)
    end
    
    @testset "Test is_convex for ValueCurves with integration" begin
        # Test that IncrementalCurve performs integration
        psd = IS.PiecewiseStepData([0.0, 1.0, 2.0], [3.0, 5.0])
        inc = IS.IncrementalCurve(psd, 10.0, 0.0)
        
        # Check convexity (should integrate)
        @test IS.is_convex(inc)
        
        # Verify integration happens by converting
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
        convex_once = IS.make_convex(psd)
        convex_twice = IS.make_convex(convex_once)
        
        @test IS.get_y_coords(convex_once) == IS.get_y_coords(convex_twice)
        @test IS.is_convex(convex_once)
        @test IS.is_convex(convex_twice)
        @test convex_twice === convex_once  # Should return same object
    end
end
