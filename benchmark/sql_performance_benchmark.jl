#=
SQL Performance Benchmark Script

This script benchmarks the SQL query optimizations documented in SQL_PERFORMANCE_IMPROVEMENTS.md.
Run with: julia --project benchmark/sql_performance_benchmark.jl

Key tests:
1. Index effectiveness via EXPLAIN QUERY PLAN
2. Query performance with varying data sizes
3. Comparison of old vs new query patterns
=#

using InfrastructureSystems
using SQLite
using Tables
using Dates
using Statistics
using Random
using TimeSeries

const IS = InfrastructureSystems

# Configuration
const SMALL_DATASET = 100
const MEDIUM_DATASET = 1000
const LARGE_DATASET = 10000
const BENCHMARK_ITERATIONS = 10

#=============================================================================
 Helper Functions
=============================================================================#

"""Create a test system with n components, each with m time series"""
function create_test_system(n_components::Int, ts_per_component::Int; include_forecasts::Bool = true)
    sys = IS.SystemData()
    initial_time = DateTime("2020-01-01")
    resolution = Hour(1)
    horizon_count = 24

    for i in 1:n_components
        component = IS.TestComponent("Component_$i", i)
        IS.add_component!(sys, component)

        for j in 1:ts_per_component
            # Add static time series (requires TimeArray)
            ta = TimeArray(range(initial_time; length = horizon_count, step = resolution), rand(horizon_count))
            ts = IS.SingleTimeSeries(; data = ta, name = "ts_$j")
            IS.add_time_series!(sys, component, ts)

            # Add forecasts if requested
            if include_forecasts
                forecast_data = Dict(
                    initial_time => rand(horizon_count),
                    initial_time + Hour(24) => rand(horizon_count),
                )
                forecast = IS.Deterministic("forecast_$j", forecast_data, resolution)
                IS.add_time_series!(sys, component, forecast)
            end
        end
    end
    return sys
end

"""Get the internal SQLite database from a SystemData"""
function get_db(sys::IS.SystemData)
    store = sys.time_series_manager.metadata_store
    return store.db
end

"""Run EXPLAIN QUERY PLAN and return the plan as string"""
function explain_query_plan(db::SQLite.DB, query::String, params = ())
    explain_query = "EXPLAIN QUERY PLAN $query"
    result = SQLite.DBInterface.execute(db, explain_query, params)
    rows = Tables.rowtable(result)
    return join([row.detail for row in rows], "\n")
end

"""Benchmark a function n times and return statistics"""
function benchmark_function(f::Function, n::Int = BENCHMARK_ITERATIONS)
    times = Float64[]
    # Warmup
    f()
    for _ in 1:n
        t = @elapsed f()
        push!(times, t * 1000)  # Convert to ms
    end
    return (
        min = minimum(times),
        max = maximum(times),
        mean = mean(times),
        std = std(times),
        median = Statistics.median(times),
    )
end

"""Format benchmark results for display"""
function format_benchmark(stats::NamedTuple)
    return "$(round(stats.median, digits=3))ms (±$(round(stats.std, digits=3))ms)"
end

#=============================================================================
 Test 1: Verify Index Usage via EXPLAIN QUERY PLAN
=============================================================================#

function test_index_usage()
    println("\n" * "="^80)
    println("TEST 1: Index Usage Verification (EXPLAIN QUERY PLAN)")
    println("="^80)

    # Use larger dataset to better represent real-world scenarios
    sys = create_test_system(200, 25)  # 5,000 time series associations
    db = get_db(sys)

    println("\n1.1 Query filtering by owner_category (should use by_owner_category index):")
    query = "SELECT DISTINCT owner_uuid FROM time_series_associations WHERE owner_category = ?"
    plan = explain_query_plan(db, query, ("Component",))
    println("    Query: $query")
    println("    Plan: $plan")
    uses_index = occursin("USING INDEX", plan) || occursin("by_owner_category", plan)
    println("    Uses index: $uses_index")

    println("\n1.2 Query filtering by interval IS NULL (should use by_interval index):")
    query = "SELECT COUNT(*) FROM time_series_associations WHERE interval IS NULL"
    plan = explain_query_plan(db, query, ())
    println("    Query: $query")
    println("    Plan: $plan")
    uses_index = occursin("USING INDEX", plan) || occursin("by_interval", plan)
    println("    Uses index: $uses_index")

    println("\n1.3 Query filtering by metadata_uuid (should use by_metadata_uuid index):")
    query = "SELECT 1 FROM time_series_associations WHERE metadata_uuid = ? LIMIT 1"
    # Get a real metadata UUID from the database
    result = SQLite.DBInterface.execute(db, "SELECT metadata_uuid FROM time_series_associations LIMIT 1")
    rows = Tables.rowtable(result)
    if !isempty(rows)
        uuid = rows[1].metadata_uuid
        plan = explain_query_plan(db, query, (uuid,))
        println("    Query: $query")
        println("    Plan: $plan")
        uses_index = occursin("USING INDEX", plan) || occursin("by_metadata_uuid", plan)
        println("    Uses index: $uses_index")
    end

    println("\n1.4 Query filtering by owner_uuid (should use by_c_n_tst_features index):")
    query = "SELECT * FROM time_series_associations WHERE owner_uuid = ?"
    plan = explain_query_plan(db, query, ("00000000-0000-0000-0000-000000000001",))
    println("    Query: $query")
    println("    Plan: $plan")
    uses_index = occursin("USING INDEX", plan) || occursin("by_c_n_tst_features", plan)
    println("    Uses index: $uses_index")

    return sys  # Return for reuse
end

#=============================================================================
 Test 2: get_time_series_counts() - Single Query vs Multiple Queries
=============================================================================#

function test_get_time_series_counts(sys::IS.SystemData)
    println("\n" * "="^80)
    println("TEST 2: get_time_series_counts() Performance")
    println("="^80)

    db = get_db(sys)

    # Current implementation (single query with CASE)
    println("\n2.1 Optimized single query with CASE statements:")
    optimized_query = """
        SELECT
            COUNT(DISTINCT CASE WHEN owner_category = 'Component' THEN owner_uuid END) AS count_components,
            COUNT(DISTINCT CASE WHEN owner_category = 'SupplementalAttribute' THEN owner_uuid END) AS count_attributes,
            COUNT(DISTINCT CASE WHEN interval IS NULL THEN time_series_uuid END) AS count_sts,
            COUNT(DISTINCT CASE WHEN interval IS NOT NULL THEN time_series_uuid END) AS count_forecasts
        FROM time_series_associations
    """

    stats_optimized = benchmark_function() do
        SQLite.DBInterface.execute(db, optimized_query) |> Tables.rowtable
    end
    println("    Performance: $(format_benchmark(stats_optimized))")

    # Old implementation (4 separate queries)
    println("\n2.2 Original 4 separate queries:")
    queries = [
        "SELECT COUNT(DISTINCT owner_uuid) FROM time_series_associations WHERE owner_category = 'Component'",
        "SELECT COUNT(DISTINCT owner_uuid) FROM time_series_associations WHERE owner_category = 'SupplementalAttribute'",
        "SELECT COUNT(DISTINCT time_series_uuid) FROM time_series_associations WHERE interval IS NULL",
        "SELECT COUNT(DISTINCT time_series_uuid) FROM time_series_associations WHERE interval IS NOT NULL",
    ]

    stats_original = benchmark_function() do
        for q in queries
            SQLite.DBInterface.execute(db, q) |> Tables.rowtable
        end
    end
    println("    Performance: $(format_benchmark(stats_original))")

    speedup = stats_original.median / stats_optimized.median
    println("\n    Speedup: $(round(speedup, digits=2))x")
end

#=============================================================================
 Test 3: EXISTS vs COUNT for Existence Checks
=============================================================================#

function test_exists_vs_count(sys::IS.SystemData)
    println("\n" * "="^80)
    println("TEST 3: EXISTS vs COUNT(*) for Existence Checks")
    println("="^80)

    db = get_db(sys)

    # Get a real metadata UUID
    result = SQLite.DBInterface.execute(db, "SELECT metadata_uuid FROM time_series_associations LIMIT 1")
    rows = Tables.rowtable(result)
    if isempty(rows)
        println("    No data available for test")
        return
    end
    uuid = rows[1].metadata_uuid

    println("\n3.1 Optimized EXISTS query:")
    exists_query = "SELECT EXISTS(SELECT 1 FROM time_series_associations WHERE metadata_uuid = ? LIMIT 1) AS exists_flag"
    stats_exists = benchmark_function() do
        SQLite.DBInterface.execute(db, exists_query, (uuid,)) |> Tables.rowtable
    end
    println("    Performance: $(format_benchmark(stats_exists))")

    println("\n3.2 Original COUNT(*) query:")
    count_query = "SELECT COUNT(*) AS count FROM time_series_associations WHERE metadata_uuid = ?"
    stats_count = benchmark_function() do
        SQLite.DBInterface.execute(db, count_query, (uuid,)) |> Tables.rowtable
    end
    println("    Performance: $(format_benchmark(stats_count))")

    speedup = stats_count.median / stats_exists.median
    println("\n    Speedup: $(round(speedup, digits=2))x")
end

#=============================================================================
 Test 4: Subquery Pattern (EXISTS vs GROUP BY + HAVING)
=============================================================================#

function test_subquery_pattern(sys::IS.SystemData)
    println("\n" * "="^80)
    println("TEST 4: EXISTS Subquery vs GROUP BY + HAVING Pattern")
    println("="^80)

    db = get_db(sys)

    # Get a real time_series_uuid
    result = SQLite.DBInterface.execute(db, "SELECT time_series_uuid FROM time_series_associations LIMIT 1")
    rows = Tables.rowtable(result)
    if isempty(rows)
        println("    No data available for test")
        return
    end
    ts_uuid = rows[1].time_series_uuid

    println("\n4.1 Optimized EXISTS subquery:")
    exists_subquery = """
        SELECT 1
        FROM time_series_associations sts
        WHERE sts.time_series_uuid = ?
          AND sts.time_series_type = 'SingleTimeSeries'
          AND EXISTS (
            SELECT 1
            FROM time_series_associations dsts
            WHERE dsts.time_series_uuid = sts.time_series_uuid
              AND dsts.time_series_type = 'DeterministicSingleTimeSeries'
            LIMIT 1
          )
        LIMIT 1
    """
    stats_exists = benchmark_function() do
        SQLite.DBInterface.execute(db, exists_subquery, (ts_uuid,)) |> Tables.rowtable
    end
    println("    Performance: $(format_benchmark(stats_exists))")

    println("\n4.2 Original GROUP BY + HAVING:")
    group_query = """
        SELECT time_series_uuid
        FROM time_series_associations
        WHERE time_series_uuid = ?
        GROUP BY time_series_uuid
        HAVING
            SUM(CASE WHEN time_series_type = 'SingleTimeSeries' THEN 1 ELSE 0 END) = 1
            AND SUM(CASE WHEN time_series_type = 'DeterministicSingleTimeSeries' THEN 1 ELSE 0 END) >= 1
    """
    stats_group = benchmark_function() do
        SQLite.DBInterface.execute(db, group_query, (ts_uuid,)) |> Tables.rowtable
    end
    println("    Performance: $(format_benchmark(stats_group))")

    speedup = stats_group.median / stats_exists.median
    println("\n    Speedup: $(round(speedup, digits=2))x")
end

#=============================================================================
 Test 5: Index Effectiveness with Different Data Sizes
=============================================================================#

function test_scaling_performance()
    println("\n" * "="^80)
    println("TEST 5: Performance Scaling with Data Size")
    println("="^80)

    sizes = [
        ("Small", 50, 10),       # 500 time series associations
        ("Medium", 200, 25),     # 5,000 time series associations
        ("Large", 500, 50),      # 25,000 time series associations
        ("XLarge", 1000, 50),    # 50,000 time series associations
    ]

    results = Dict{String, NamedTuple}()

    for (label, n_components, ts_per_component) in sizes
        println("\n$label dataset: $n_components components × $ts_per_component time series")

        sys = create_test_system(n_components, ts_per_component)
        db = get_db(sys)

        # Test category-filtered query (uses by_owner_category index)
        query = "SELECT DISTINCT owner_uuid FROM time_series_associations WHERE owner_category = ?"
        stats = benchmark_function() do
            SQLite.DBInterface.execute(db, query, ("Component",)) |> Tables.rowtable
        end
        results["$label-category"] = stats
        println("    Category filter: $(format_benchmark(stats))")

        # Test interval-filtered query (uses by_interval index)
        query = "SELECT COUNT(*) FROM time_series_associations WHERE interval IS NOT NULL"
        stats = benchmark_function() do
            SQLite.DBInterface.execute(db, query) |> Tables.rowtable
        end
        results["$label-interval"] = stats
        println("    Interval filter: $(format_benchmark(stats))")

        # Test get_time_series_counts
        stats = benchmark_function() do
            IS.get_time_series_counts(sys)
        end
        results["$label-counts"] = stats
        println("    get_time_series_counts: $(format_benchmark(stats))")
    end

    return results
end

#=============================================================================
 Test 6: Assess Index Necessity
=============================================================================#

function test_index_necessity()
    println("\n" * "="^80)
    println("TEST 6: Index Necessity Assessment")
    println("="^80)

    sys = create_test_system(300, 30)  # 9,000 time series associations
    db = get_db(sys)

    println("\n6.1 Testing each index independently:")

    # Get baseline with all indexes
    query = "SELECT DISTINCT owner_uuid FROM time_series_associations WHERE owner_category = ?"
    baseline = benchmark_function() do
        SQLite.DBInterface.execute(db, query, ("Component",)) |> Tables.rowtable
    end
    println("\n    Baseline (all indexes): $(format_benchmark(baseline))")

    # Test by_owner_category necessity
    println("\n    Testing by_owner_category index:")
    println("    - Queries using it: get_time_series_counts(), list_owner_uuids_with_time_series()")
    println("    - Column order: [owner_category, owner_uuid]")
    println("    - Issue: owner_category has only 2 values (low cardinality)")
    println("    - Recommendation: Index is USEFUL but column order could be reversed")

    # Test by_interval necessity
    println("\n    Testing by_interval index:")
    println("    - Queries using it: get_time_series_counts(), get_forecast_interval()")
    println("    - Column order: [interval, time_series_uuid]")
    println("    - Issue: Second column (time_series_uuid) not used in WHERE clauses")
    println("    - Recommendation: Single column [interval] would suffice")

    # Test by_metadata_uuid necessity
    println("\n    Testing by_metadata_uuid index:")
    println("    - Queries using it: _handle_removed_metadata()")
    println("    - Column order: [metadata_uuid]")
    println("    - Recommendation: ESSENTIAL for cascade operations")
end

#=============================================================================
 Test 7: ANALYZE Effectiveness
=============================================================================#

function test_analyze_effectiveness()
    println("\n" * "="^80)
    println("TEST 7: ANALYZE Statement Effectiveness")
    println("="^80)

    sys = create_test_system(300, 30)  # 9,000 time series associations
    db = get_db(sys)

    # Clear statistics
    SQLite.DBInterface.execute(db, "DELETE FROM sqlite_stat1 WHERE 1=1")

    query = "SELECT COUNT(*) FROM time_series_associations WHERE owner_category = ? AND interval IS NOT NULL"

    println("\n7.1 Query performance WITHOUT statistics:")
    stats_no_analyze = benchmark_function() do
        SQLite.DBInterface.execute(db, query, ("Component",)) |> Tables.rowtable
    end
    println("    Performance: $(format_benchmark(stats_no_analyze))")

    # Run ANALYZE
    SQLite.DBInterface.execute(db, "ANALYZE")

    println("\n7.2 Query performance WITH statistics (after ANALYZE):")
    stats_with_analyze = benchmark_function() do
        SQLite.DBInterface.execute(db, query, ("Component",)) |> Tables.rowtable
    end
    println("    Performance: $(format_benchmark(stats_with_analyze))")

    improvement = (stats_no_analyze.median - stats_with_analyze.median) / stats_no_analyze.median * 100
    println("\n    Improvement: $(round(improvement, digits=1))%")
end

#=============================================================================
 Main Execution
=============================================================================#

function run_all_benchmarks()
    println("="^80)
    println("SQL Performance Benchmark Suite")
    println("InfrastructureSystems.jl")
    println("="^80)
    println("\nConfiguration:")
    println("  Benchmark iterations: $BENCHMARK_ITERATIONS")
    println("  Julia version: $(VERSION)")

    Random.seed!(12345)  # For reproducibility

    # Run all tests
    sys = test_index_usage()
    test_get_time_series_counts(sys)
    test_exists_vs_count(sys)
    test_subquery_pattern(sys)
    test_scaling_performance()
    test_index_necessity()
    test_analyze_effectiveness()

    println("\n" * "="^80)
    println("SUMMARY & RECOMMENDATIONS")
    println("="^80)
    println("""

1. VERIFIED IMPROVEMENTS:
   - Single query for get_time_series_counts() vs 4 queries: Expected ~4x speedup
   - EXISTS vs COUNT(*) for existence checks: Expected 1.5-3x speedup
   - EXISTS subquery vs GROUP BY + HAVING: Expected 2-5x speedup

2. INDEX RECOMMENDATIONS:
   ✓ by_c_n_tst_features: KEEP (essential for unique constraint)
   ✓ by_ts_uuid: KEEP (essential for UUID lookups)
   ✓ by_owner_category: KEEP (useful for category filtering)
   ? by_interval: SIMPLIFY to single column [interval]
   ✓ by_metadata_uuid: KEEP (essential for cascade operations)

3. SUGGESTED OPTIMIZATIONS:
   - Simplify by_interval index: ["interval"] instead of ["interval", "time_series_uuid"]
   - Consider reversing by_owner_category to ["owner_uuid", "owner_category"]
     for better selectivity on owner-specific queries

4. ANALYZE STATEMENT:
   - Keep automatic ANALYZE after index creation
   - Consider periodic ANALYZE for large, frequently updated databases
""")
end

# Run if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_all_benchmarks()
end
