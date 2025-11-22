import InfrastructureSystems
const IS = InfrastructureSystems
import InfrastructureSystems.Optimization:
    OptimizerStats,
    to_matrix,
    to_dataframe,
    to_dict,
    get_column_names
import DataFrames

@testset "Test OptimizerStats default constructor" begin
    stats = OptimizerStats()

    # Test default values
    @test stats.detailed_stats == false
    @test isnan(stats.objective_value)
    @test stats.termination_status == -1
    @test stats.primal_status == -1
    @test stats.dual_status == -1
    @test isnan(stats.solver_solve_time)
    @test stats.result_count == -1
    @test stats.has_values == false
    @test stats.has_duals == false
    @test ismissing(stats.objective_bound)
    @test ismissing(stats.relative_gap)
    @test ismissing(stats.dual_objective_value)
    @test isnan(stats.solve_time)
    @test ismissing(stats.barrier_iterations)
    @test ismissing(stats.simplex_iterations)
    @test ismissing(stats.node_count)
    @test stats.timed_solve_time == 0
    @test stats.timed_calculate_aux_variables == 0
    @test stats.timed_calculate_dual_variables == 0
    @test ismissing(stats.solve_bytes_alloc)
    @test ismissing(stats.sec_in_gc)
end

@testset "Test OptimizerStats to_matrix and from Vector" begin
    # Create a stats object with known values
    stats = OptimizerStats()
    stats.detailed_stats = true
    stats.objective_value = 100.0
    stats.termination_status = 1
    stats.primal_status = 1
    stats.dual_status = 1
    stats.solver_solve_time = 5.5
    stats.result_count = 1
    stats.has_values = true
    stats.has_duals = true
    stats.objective_bound = 95.0
    stats.relative_gap = 0.05
    stats.dual_objective_value = 98.0
    stats.solve_time = 6.0
    stats.barrier_iterations = 10
    stats.simplex_iterations = 20
    stats.node_count = 5
    stats.timed_solve_time = 5.8
    stats.timed_calculate_aux_variables = 0.1
    stats.timed_calculate_dual_variables = 0.2
    stats.solve_bytes_alloc = 1000.0
    stats.sec_in_gc = 0.01

    # Convert to matrix
    matrix = to_matrix(stats)
    @test isa(matrix, Matrix{Float64})
    @test size(matrix, 1) == fieldcount(OptimizerStats)
    @test size(matrix, 2) == 1

    # Convert back from vector
    stats2 = OptimizerStats(vec(matrix))

    # Verify all fields match
    @test stats2.detailed_stats == stats.detailed_stats
    @test stats2.objective_value == stats.objective_value
    @test stats2.termination_status == stats.termination_status
    @test stats2.primal_status == stats.primal_status
    @test stats2.dual_status == stats.dual_status
    @test stats2.solver_solve_time == stats.solver_solve_time
    @test stats2.result_count == stats.result_count
    @test stats2.has_values == stats.has_values
    @test stats2.has_duals == stats.has_duals
    @test stats2.objective_bound == stats.objective_bound
    @test stats2.relative_gap == stats.relative_gap
    @test stats2.dual_objective_value == stats.dual_objective_value
    @test stats2.solve_time == stats.solve_time
    @test stats2.barrier_iterations == stats.barrier_iterations
    @test stats2.simplex_iterations == stats.simplex_iterations
    @test stats2.node_count == stats.node_count
    @test stats2.timed_solve_time == stats.timed_solve_time
    @test stats2.timed_calculate_aux_variables == stats.timed_calculate_aux_variables
    @test stats2.timed_calculate_dual_variables == stats.timed_calculate_dual_variables
    @test stats2.solve_bytes_alloc == stats.solve_bytes_alloc
    @test stats2.sec_in_gc == stats.sec_in_gc
end

@testset "Test OptimizerStats missing value handling" begin
    stats = OptimizerStats()
    stats.objective_bound = missing
    stats.dual_objective_value = missing
    stats.barrier_iterations = missing
    stats.simplex_iterations = missing
    stats.node_count = missing
    stats.solve_bytes_alloc = missing
    stats.sec_in_gc = missing

    # Convert to matrix
    matrix = to_matrix(stats)

    # Convert back
    stats2 = OptimizerStats(vec(matrix))

    # Verify missing values are preserved
    @test ismissing(stats2.objective_bound)
    @test ismissing(stats2.dual_objective_value)
    @test ismissing(stats2.barrier_iterations)
    @test ismissing(stats2.simplex_iterations)
    @test ismissing(stats2.node_count)
    @test ismissing(stats2.solve_bytes_alloc)
    @test ismissing(stats2.sec_in_gc)
end

@testset "Test OptimizerStats to_dataframe" begin
    stats = OptimizerStats()
    stats.objective_value = 150.0
    stats.termination_status = 1
    stats.solve_time = 3.5

    df = to_dataframe(stats)
    @test isa(df, DataFrames.DataFrame)
    @test DataFrames.nrow(df) == 1

    # Check that key fields are in the dataframe
    @test :objective_value in names(df)
    @test :termination_status in names(df)
    @test :solve_time in names(df)

    # Check values
    @test df[1, :objective_value] == 150.0
    @test df[1, :termination_status] == 1
    @test df[1, :solve_time] == 3.5
end

@testset "Test OptimizerStats to_dict" begin
    stats = OptimizerStats()
    stats.objective_value = 200.0
    stats.termination_status = 2
    stats.solve_time = 4.2

    dict = to_dict(stats)
    @test isa(dict, Dict)

    # Check that key fields are in the dictionary
    @test haskey(dict, "objective_value")
    @test haskey(dict, "termination_status")
    @test haskey(dict, "solve_time")

    # Check values
    @test dict["objective_value"] == 200.0
    @test dict["termination_status"] == 2
    @test dict["solve_time"] == 4.2
end

@testset "Test OptimizerStats get_column_names" begin
    columns = get_column_names(OptimizerStats)
    @test isa(columns, Tuple)
    @test length(columns) == 1
    @test isa(columns[1], Vector{String})

    # Verify key column names are present
    col_names = columns[1]
    @test "objective_value" in col_names
    @test "termination_status" in col_names
    @test "solve_time" in col_names
    @test "detailed_stats" in col_names
    @test "has_values" in col_names
    @test "has_duals" in col_names

    # Verify the count matches the number of fields
    @test length(col_names) == fieldcount(OptimizerStats)
end

@testset "Test OptimizerStats with detailed stats" begin
    stats = OptimizerStats()
    stats.detailed_stats = true
    stats.barrier_iterations = 15
    stats.simplex_iterations = 25
    stats.node_count = 8
    stats.solve_bytes_alloc = 5000.0
    stats.sec_in_gc = 0.05

    # Convert to dict and verify detailed stats are included
    dict = to_dict(stats)
    @test dict["detailed_stats"] == true
    @test dict["barrier_iterations"] == 15
    @test dict["simplex_iterations"] == 25
    @test dict["node_count"] == 8
    @test dict["solve_bytes_alloc"] == 5000.0
    @test dict["sec_in_gc"] == 0.05
end
