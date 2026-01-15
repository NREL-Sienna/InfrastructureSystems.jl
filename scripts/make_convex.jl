# Convexity Analysis Script
#
# This script analyzes and convexifies non-convex cost curves in a PowerSystems model.
# It processes ThermalStandard generators with FuelCurve variable costs, attempts to
# convexify their underlying curve data, and reports approximation errors and statistics.
#
# Usage:
#   1. Update sys_path to point to your system JSON file
#   2. In julia repl: include("scripts/make_convex.jl")
#
# The script:
#   - Loads a PowerSystems model from JSON
#   - Iterates through ThermalStandard generators with FuelCurve variable costs
#   - Attempts convexification using make_convex() on underlying curve data
#   - Calculates L2 approximation errors between original and convexified curves
#   - Generates statistics and visualizations (histogram and PDF of errors)
#   - Exports results to CSV with error metrics and percentiles
#
# Note: Successfully tested with PiecewiseLinearData curves. Not tested with other curve types.
# Did not encounter any error with any of the IS methods. 

using PowerSystems
using DataFrames
using CSV
using Statistics
using Plots
using StatsPlots
using InfrastructureSystems
include("src/function_data.jl")

# Load system with non-convex generators
sys_path = "/path/to/nonconvex_generators.json"
sys = System(sys_path)

# Initialize results DataFrame
results = DataFrame(
    generator_name = String[],
    curve_type = String[],
    original_curve = Any[],
    convexified_curve = Any[],
    error_L2 = Float64[],
    convexified_successfully = Bool[]
)

for gen in get_components(ThermalStandard, sys)
    gen_name = get_name(gen)
    var_cost = get_variable(get_operation_cost(gen))
    
    if var_cost isa FuelCurve
        cost_data = get_value_curve(var_cost)
        curve_type = string(typeof(cost_data))
        
        convexified = nothing
        error_val = NaN
        success = false
        
        try
            # Extract underlying function data if it's a ValueCurve wrapper
            underlying_data = hasfield(typeof(cost_data), :function_data) ? 
                              getfield(cost_data, :function_data) : cost_data
            
            if underlying_data isa PiecewiseLinearData
                convexified = make_convex(underlying_data)
                error_val = approximation_error(underlying_data, convexified)
                success = true
            elseif underlying_data isa PiecewiseStepData
                convexified = make_convex(underlying_data)
                error_val = approximation_error(underlying_data, convexified)
                success = true
            end
        catch e
            @warn "Failed to convexify $gen_name" exception=e
        end
        
        push!(results, (gen_name, curve_type, cost_data, convexified, error_val, success))
    end
end

# Print curve type breakdown
println("\n=== Curve Type Breakdown ===")
curve_counts = combine(groupby(results, :curve_type), nrow => :count)
println(curve_counts)

# Print convexification results
println("\n=== Convexification Results ===")
println("Total curves: $(nrow(results))")
println("Successfully convexified: $(sum(results.convexified_successfully))")
println("Failed to convexify: $(sum(.!results.convexified_successfully))")

# Calculate percentiles for all results
results.error_percentile = fill(NaN, nrow(results))
successful_errors = results[results.convexified_successfully, :error_L2]

for i in 1:nrow(results)
    if results.convexified_successfully[i]
        results.error_percentile[i] = mean(successful_errors .<= results.error_L2[i]) * 100
    end
end

# Compute statistics on successful convexifications
successful = results[results.convexified_successfully, :]
if nrow(successful) > 0
    println("\n=== Approximation Error Statistics (L2) ===")
    println("Mean: $(mean(successful.error_L2))")
    println("Median: $(median(successful.error_L2))")
    println("Std: $(std(successful.error_L2))")
    println("Min: $(minimum(successful.error_L2))")
    println("Max: $(maximum(successful.error_L2))")
    
    # Plot histogram of errors
    p1 = histogram(successful.error_L2, 
                   bins = 50,
                   xlabel = "L2 Approximation Error",
                   ylabel = "Frequency",
                   title = "Distribution of Convexification Errors",
                   legend = false,
                   normalize = false)
    savefig(p1, "scripts/convexity/figures/error_histogram.png")
    println("\nHistogram saved to scripts/convexity/figures/error_histogram.png")
    
    # Plot PDF (kernel density estimate) using StatsPlots
    p2 = @df DataFrame(error=successful.error_L2) density(:error,
                 xlabel = "L2 Approximation Error",
                 ylabel = "Density",
                 title = "PDF of Convexification Errors",
                 legend = false,
                 fill = (0, 0.3),
                 linewidth = 2)
    savefig(p2, "scripts/convexity/figures/error_pdf.png")
    println("PDF saved to scripts/convexity/figures/error_pdf.png")
end

# Save results to CSV
CSV.write("scripts/convexity/datasets/convexification_results.csv", 
          select(results, :generator_name, :curve_type, :error_L2, :error_percentile, :convexified_successfully))
println("\nResults saved to scripts/convexity/datasets/convexification_results.csv")

println("\n" * "="^80)
println("To plot individual generator comparisons, run:")
println("  include(\"scripts/convexity/plot_utils.jl\")")
println("  plot_convexification_comparison(\"generator-name\", sys)")
println("="^80)