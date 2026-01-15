import InfrastructureSystems.Optimization: OptimizerStats
import InfrastructureSystems as IS
@testset "Test OptimizerStats" begin
    empty_stats = OptimizerStats()
    @test isa(IS.Optimization.get_column_names(OptimizerStats), Tuple{Vector{String}})
    @test length(IS.Optimization.get_column_names(OptimizerStats)[1]) == 21
    data = [
        1.0,
        100.0,
        1.0,
        1.0,
        2.0,
        10.0,
        1.0,
        1.0,
        0.0,
        -100.0,
        0.01,
        -100.0,
        100.0,
        NaN,
        NaN,
        10.0,
        10.0,
        1.0,
        0.0,
        0.0,
        0.0,
    ]
    populated_stats = OptimizerStats(data)
    stats_mat = IS.Optimization.to_matrix(populated_stats)
    for (ix, val) in enumerate(stats_mat)
        if isfinite(val)
            @test val == data[ix]
        elseif isnan(val)
            @test isnan(data[ix])
        else
            @test false
        end
    end
    stats_dict = IS.Optimization.to_dict(populated_stats)
    @test isa(stats_dict["barrier_iterations"], Missing)
    @test isa(stats_dict["simplex_iterations"], Missing)
    @test length(stats_dict) == 21
    stats_df = IS.Optimization.to_dataframe(populated_stats)
    @test stats_df[!, "detailed_stats"][1] == true
    @test isa(stats_df[!, "barrier_iterations"][1], Missing)
    @test isa(stats_df[!, "simplex_iterations"][1], Missing)
end
