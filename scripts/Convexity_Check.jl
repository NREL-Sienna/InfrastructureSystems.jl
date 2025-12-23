 # Non-convexity check script for generator cost curves
# Outputs: console summary + non_convex_generators.json

using PowerSystems
using InfrastructureSystems
const PSY = PowerSystems
const IS = InfrastructureSystems
# System path - edit as needed
const sys_json_path = "/path/to/your/system.json"

function check_nonconvex(curve)
    # Check if a curve is non-convex using IS.is_nonconvex. Returns a boolean.
    try
        if isa(curve, InfrastructureSystems.PiecewiseIncrementalCurve)
            # Extract the underlying piecewise data and check for non-convexity
            function_data = PSY.get_function_data(curve)
            return IS.is_nonconvex(function_data)
        elseif isa(curve, PSY.PiecewiseLinearCurve)
            # Extract the underlying piecewise data and check for non-convexity
            function_data = PSY.get_function_data(curve)
            return IS.is_nonconvex(function_data)
        elseif isa(curve, PSY.QuadraticCurve)
            # Extract function data and check for non-convexity
            function_data = PSY.get_function_data(curve)
            return IS.is_nonconvex(function_data)
        elseif isa(curve, PSY.LinearCurve)
            # Extract function data and check for non-convexity (always false for linear)
            function_data = PSY.get_function_data(curve)
            return IS.is_nonconvex(function_data)
        else
            @warn "Unknown curve type: $(typeof(curve))"
            return missing
        end
    catch e
        @warn "Non-convexity check exception: $e"
        return missing
    end
end

function analyze_generator(gen::PSY.ThermalStandard)
    # Check if a generator has a non-convex cost curve.
    try
        op_cost = PSY.get_operation_cost(gen)
        if isnothing(op_cost)
            return missing
        end
        var_cost = PSY.get_variable(op_cost)
        if isnothing(var_cost)
            return missing
        end
        
        curve = PSY.get_value_curve(var_cost)
        if isnothing(curve)
            return missing
        end
        
        return check_nonconvex(curve)
    catch e
        @warn "Exception analyzing generator $(gen.name): $e"
        return missing
    end
end

function main()
    if isdefined(Main, :sys)
        println("System already loaded.")
    else
        println("Loading system from: $sys_json_path")
        global sys = System(sys_json_path)
    end
    
    gens = collect(get_components(PSY.ThermalStandard, sys))
    n_total = length(gens)
    
    nonconvex_gens = String[]
    convex_gens = String[]
    missing_data_gens = String[]
    
    for gen in gens
        is_nonconvex_result = analyze_generator(gen)
        
        if ismissing(is_nonconvex_result)
            push!(missing_data_gens, gen.name)
        elseif is_nonconvex_result
            push!(nonconvex_gens, gen.name)
        else
            push!(convex_gens, gen.name)
        end
    end
    
    n_nonconvex = length(nonconvex_gens)
    n_convex = length(convex_gens)
    n_missing = length(missing_data_gens)
    
    # Print summary
    println("\n" * "="^80)
    println("NON-CONVEXITY CHECK SUMMARY")
    println("="^80)
    println("\nTotal generators analyzed: $n_total")
    println("\nConvex curves: $n_convex generators")
    println("Non-convex curves: $n_nonconvex generators")
    println("Missing/invalid cost data: $n_missing generators")
    
    if n_nonconvex > 0
        println("\nNon-convex generators (showing first 10):")
        nshow = min(n_nonconvex, 10)
        for i in 1:nshow
            println("  $(i). $(nonconvex_gens[i])")
        end
        if n_nonconvex > 10
            println("  ... and $(n_nonconvex - 10) more")
        end
    end
    
    # Save non-convex generators to a new system
    output_path = joinpath(dirname(@__FILE__), "nonconvex_generators.json")
    
    if n_nonconvex > 0
        # Create a copy of the system
        nonconvex_sys = deepcopy(sys)
        
        # Get all thermal generators and remove the ones that are not non-convex
        all_gens_in_copy = collect(get_components(PSY.ThermalStandard, nonconvex_sys))
        nonconvex_set = Set(nonconvex_gens)
        
        for gen in all_gens_in_copy
            if !(gen.name in nonconvex_set)
                remove_component!(nonconvex_sys, gen)
            end
        end
        
        PSY.to_json(nonconvex_sys, output_path; force=true)
        
        println("\n" * "="^80)
        println("System with non-convex generators saved to: $output_path")
        println("Contains $n_nonconvex non-convex generators")
        println("="^80 * "\n")
    else
        println("\n" * "="^80)
        println("No non-convex generators found - no output file created")
        println("="^80 * "\n")
    end
    
    return 0
end

# Run the script
main()