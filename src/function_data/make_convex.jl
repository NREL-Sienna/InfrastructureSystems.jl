# CONVEX APPROXIMATION UTILS
# Functions for transforming non-convex curves into convex approximations.

# ============================================================================
# COLINEARITY CLEANUP UTILS
# Functions for removing artificial segmentation from piecewise curves.
# ============================================================================

const _COLINEARITY_TOLERANCE = 1e-6

"""
    merge_colinear_segments(curve::ValueCurve; ε::Float64 = _COLINEARITY_TOLERANCE, generator_name::Union{String, Nothing} = nothing) -> ValueCurve

Merge consecutive colinear segments in a piecewise curve.

Colinear segments are identified by grouping: starting from the first segment in a group,
all subsequent segments whose slope differs from the group's first slope by less than ε
are merged. This cleanup step removes artificial segmentation that can cause false
non-convex detections, unnecessary curve complexity, and unstable numerical behavior.

# Arguments
- `curve`: A piecewise `ValueCurve` to clean up
- `ε`: Tolerance for comparing slopes (default: `$(_COLINEARITY_TOLERANCE)`)
- `generator_name`: Optional generator name for logging (default: `nothing`)

# Returns
A new curve with colinear segments merged. Endpoints are preserved exactly.
Returns the original curve unchanged if no colinear segments are found.
When segments are merged, an `@info` log is printed indicating the merge occurred.

# Supported curve types
- `PiecewisePointCurve` (InputOutputCurve{PiecewiseLinearData})
- `PiecewiseIncrementalCurve` (IncrementalCurve{PiecewiseStepData})
- `PiecewiseAverageCurve` (AverageRateCurve{PiecewiseStepData})
"""
function merge_colinear_segments end

"""
    merge_colinear_segments(curve::PiecewisePointCurve; ε) -> PiecewisePointCurve

Merge colinear segments in a `PiecewisePointCurve` (InputOutputCurve{PiecewiseLinearData}).

Algorithm:
1. Compute slopes between consecutive points
2. Identify groups of consecutive segments with slopes within tolerance ε
3. For each colinear group, keep only the first and last points
4. Preserve first and last endpoints exactly
"""
function merge_colinear_segments(
    curve::InputOutputCurve{PiecewiseLinearData};
    ε::Float64 = _COLINEARITY_TOLERANCE,
    generator_name::Union{String, Nothing} = nothing,
)
    fd = get_function_data(curve)
    points = get_points(fd)
    n_points = length(points)

    # Edge cases: 0, 1, or 2 points - no segments to merge
    n_points <= 2 && return curve

    slopes = get_slopes(fd)
    n_slopes = length(slopes)

    # Build list of point indices to keep
    # Always keep first point
    keep_indices = Int[1]

    i = 1
    while i < n_slopes
        # Find the end of the current colinear group
        current_slope = slopes[i]
        j = i
        while j < n_slopes && abs(slopes[j + 1] - current_slope) <= ε
            j += 1
        end

        # Keep the endpoint of this group (which is also the start of the next)
        push!(keep_indices, j + 1)
        i = j + 1
    end

    # Always ensure last point is included
    if keep_indices[end] != n_points
        push!(keep_indices, n_points)
    end

    # If no reduction, return original
    length(keep_indices) == n_points && return curve

    # Log the merge
    gen_msg = isnothing(generator_name) ? "" : " for generator $(generator_name)"
    @info "Merged colinear segments$(gen_msg)"

    # Build new points array
    new_points = [points[i] for i in keep_indices]

    return InputOutputCurve(PiecewiseLinearData(new_points), get_input_at_zero(curve))
end

"""
    merge_colinear_segments(curve::PiecewiseIncrementalCurve; ε) -> PiecewiseIncrementalCurve

Merge colinear segments in a `PiecewiseIncrementalCurve` (IncrementalCurve{PiecewiseStepData}).

For step data, slopes are directly stored as y-coordinates.
Consecutive steps with y-values within tolerance ε are merged.
"""
function merge_colinear_segments(
    curve::IncrementalCurve{PiecewiseStepData};
    ε::Float64 = _COLINEARITY_TOLERANCE,
    generator_name::Union{String, Nothing} = nothing,
)
    fd = get_function_data(curve)
    x_coords = get_x_coords(fd)
    y_coords = get_y_coords(fd)  # These are the slopes/marginal rates

    n_segments = length(y_coords)

    # Edge cases: 0 or 1 segment - nothing to merge
    n_segments <= 1 && return curve

    # Build merged x and y coordinates
    new_x = Float64[x_coords[1]]
    new_y = Float64[]

    i = 1
    while i <= n_segments
        current_slope = y_coords[i]
        j = i

        # Find the end of the current colinear group
        while j < n_segments && abs(y_coords[j + 1] - current_slope) <= ε
            j += 1
        end

        # Add the merged segment
        push!(new_x, x_coords[j + 1])  # End x-coordinate of the merged segment
        push!(new_y, current_slope)    # Use the first slope of the group

        i = j + 1
    end

    # If no reduction, return original
    length(new_y) == n_segments && return curve

    # Log the merge
    gen_msg = isnothing(generator_name) ? "" : " for generator $(generator_name)"
    @info "Merged colinear segments$(gen_msg)"

    return IncrementalCurve(
        PiecewiseStepData(new_x, new_y),
        get_initial_input(curve),
        get_input_at_zero(curve),
    )
end

"""
    merge_colinear_segments(curve::PiecewiseAverageCurve; ε) -> PiecewiseAverageCurve

Merge colinear segments in a `PiecewiseAverageCurve` (AverageRateCurve{PiecewiseStepData}).

For step data, average rates are directly stored as y-coordinates.
Consecutive steps with y-values within tolerance ε are merged.
"""
function merge_colinear_segments(
    curve::AverageRateCurve{PiecewiseStepData};
    ε::Float64 = _COLINEARITY_TOLERANCE,
    generator_name::Union{String, Nothing} = nothing,
)
    fd = get_function_data(curve)
    x_coords = get_x_coords(fd)
    y_coords = get_y_coords(fd)  # These are the average rates

    n_segments = length(y_coords)

    # Edge cases: 0 or 1 segment - nothing to merge
    n_segments <= 1 && return curve

    # Build merged x and y coordinates
    new_x = Float64[x_coords[1]]
    new_y = Float64[]

    i = 1
    while i <= n_segments
        current_rate = y_coords[i]
        j = i

        # Find the end of the current colinear group
        while j < n_segments && abs(y_coords[j + 1] - current_rate) <= ε
            j += 1
        end

        # Add the merged segment
        push!(new_x, x_coords[j + 1])  # End x-coordinate of the merged segment
        push!(new_y, current_rate)     # Use the first rate of the group

        i = j + 1
    end

    # If no reduction, return original
    length(new_y) == n_segments && return curve

    # Log the merge
    gen_msg = isnothing(generator_name) ? "" : " for generator $(generator_name)"
    @info "Merged colinear segments$(gen_msg)"

    return AverageRateCurve(
        PiecewiseStepData(new_x, new_y),
        get_initial_input(curve),
        get_input_at_zero(curve),
    )
end

# ============================================================================
# CONVEXIFICATION UTILITIES
# ============================================================================

"""
    increasing_curve_convex_approximation(curve::ValueCurve; kwargs...) -> Union{ValueCurve, Nothing}

Transform a strictly increasing `ValueCurve` into a convex form, with data quality validation.

This function first validates that the curve data is reasonable and physically meaningful
using [`is_valid_data`](@ref). It also checks that the curve is strictly increasing using
[`is_strictly_increasing`](@ref). If either check fails, the function logs an error and 
returns `nothing` to trigger a fallback path.

If the data passes validation and is already convex, returns the original curve 
(optionally with colinear segments merged).

If the data passes validation but is non-convex, applies isotonic regression to 
produce a convex approximation.

# Supported curve types
- `InputOutputCurve{PiecewiseLinearData}`: Isotonic regression on slopes
- `IncrementalCurve{PiecewiseStepData}`: Converts to IO curve, makes convex, converts back
- `AverageRateCurve{PiecewiseStepData}`: Converts to IO curve, makes convex, converts back

Note 1: `IncrementalCurve{LinearFunctionData}` and `AverageRateCurve{LinearFunctionData}` are
intentionally NOT supported. These represent derivatives of quadratic functions and rarely
appear in real data. The arbitrary projection approach used for quadratics is not appropriate.
Note 2: `InputOutputCurve{LinearFunctionData}` is not supported because it never presents convexity issues. 
Note 3: `InputOutputCurve{QuadraticFunctionData}` is not supported given that it represents a significant change on the curve

# Keyword Arguments
- `weights::Symbol`: Weighting scheme for isotonic regression (affects how violations are resolved)
  - `:length` (default): weight segments by x-extent (wider segments have more influence)
  - `:uniform`: all segments equally weighted
- `anchor`: Point preservation strategy for reconstructing points from new slopes
  - `:first` (default): preserve first point, propagate forward
  - `:last`: preserve last point, propagate backward
  - `:centroid`: minimize total vertical displacement
- `merge_colinear`: Whether to merge colinear segments before convexification (default: `true`)
  - Colinear segments are those where consecutive slopes differ by less than a tolerance
  - This cleanup step removes artificial segmentation that can cause false non-convex detections

# Returns
- The convex curve (original or approximation) if successful
- `nothing` if data quality validation fails or curve is not strictly increasing

# See also
- [`decreasing_curve_convex_approximation`](@ref): for strictly decreasing curves
"""
function increasing_curve_convex_approximation end

"""
    increasing_curve_convex_approximation(curve::InputOutputCurve{PiecewiseLinearData}; kwargs...) -> Union{InputOutputCurve{PiecewiseLinearData}, Nothing}"""
function increasing_curve_convex_approximation(
    curve::InputOutputCurve{PiecewiseLinearData};
    weights::Symbol = :length,
    anchor::Symbol = :first,
    merge_colinear::Bool = true,
    generator_name::Union{String, Nothing} = nothing,
    _skip_validation::Bool = false,
)
    gen_msg = isnothing(generator_name) ? "" : " for generator $(generator_name)"

    # Data quality validation - check for fundamentally invalid data
    if !_skip_validation && !is_valid_data(curve)
        @error "Invalid curve data$(gen_msg): data quality validation failed"
        return nothing
    end

    # Check that the curve is strictly increasing (cost should increase with output)
    if !_skip_validation && !is_strictly_increasing(curve)
        @error "Invalid curve data$(gen_msg): curve is not strictly increasing"
        return nothing
    end

    # If already convex, optionally clean up colinear segments and return
    if is_convex(curve)
        return merge_colinear ? merge_colinear_segments(curve; generator_name = generator_name) : curve
    end

    fd = get_function_data(curve)
    points = get_points(fd)
    x_coords = get_x_coords(fd)
    slopes = get_slopes(fd)

    w = _compute_convex_weights(x_coords, weights)
    new_slopes = isotonic_regression(slopes, w)
    new_points = _reconstruct_points(points, new_slopes, anchor)

    @warn "Transformed non-convex InputOutputCurve to convex approximation$(gen_msg)"
    result = InputOutputCurve(PiecewiseLinearData(new_points), get_input_at_zero(curve))

    # Clean up any colinear segments (from original data or produced by isotonic regression)
    return if merge_colinear
        merge_colinear_segments(result; generator_name = generator_name)
    else
        result
    end
end

"""
    increasing_curve_convex_approximation(curve::IncrementalCurve{PiecewiseStepData}; kwargs...) -> Union{IncrementalCurve{PiecewiseStepData}, Nothing}
"""
function increasing_curve_convex_approximation(
    curve::IncrementalCurve{PiecewiseStepData};
    weights::Symbol = :length,
    anchor::Symbol = :first,
    merge_colinear::Bool = true,
    generator_name::Union{String, Nothing} = nothing,
)
    gen_msg = isnothing(generator_name) ? "" : " for generator $(generator_name)"

    # Data quality validation - check for fundamentally invalid data
    if !is_valid_data(curve)
        @error "Invalid curve data$(gen_msg): data quality validation failed"
        return nothing
    end

    # Check that the curve is strictly increasing (cost should increase with output)
    if !is_strictly_increasing(curve)
        @error "Invalid curve data$(gen_msg): curve is not strictly increasing"
        return nothing
    end

    # If already convex, optionally clean up colinear segments and return
    if is_convex(curve)
        return if merge_colinear
            merge_colinear_segments(curve; generator_name = generator_name)
        else
            curve
        end
    end

    # Convert to InputOutputCurve, make convex, convert back
    io_curve = InputOutputCurve(curve)
    convex_io = increasing_curve_convex_approximation(
        io_curve;
        weights = weights,
        anchor = anchor,
        merge_colinear = false,
        generator_name = generator_name,
        _skip_validation = true,  # Already validated above
    )
    isnothing(convex_io) && return nothing

    @warn "Transformed non-convex IncrementalCurve to convex approximation$(gen_msg)"
    result = IncrementalCurve(convex_io)

    # Clean up any colinear segments (from original data or produced by convexification)
    return if merge_colinear
        merge_colinear_segments(result; generator_name = generator_name)
    else
        result
    end
end

"""
    increasing_curve_convex_approximation(curve::AverageRateCurve{PiecewiseStepData}; kwargs...) -> Union{AverageRateCurve{PiecewiseStepData}, Nothing}"""
function increasing_curve_convex_approximation(
    curve::AverageRateCurve{PiecewiseStepData};
    weights::Symbol = :length,
    anchor::Symbol = :first,
    merge_colinear::Bool = true,
    generator_name::Union{String, Nothing} = nothing,
)
    gen_msg = isnothing(generator_name) ? "" : " for generator $(generator_name)"

    # Data quality validation - check for fundamentally invalid data
    if !is_valid_data(curve)
        @error "Invalid curve data$(gen_msg): data quality validation failed"
        return nothing
    end

    # Check that the curve is strictly increasing (cost should increase with output)
    if !is_strictly_increasing(curve)
        @error "Invalid curve data$(gen_msg): curve is not strictly increasing"
        return nothing
    end

    # If already convex, optionally clean up colinear segments and return
    if is_convex(curve)
        return if merge_colinear
            merge_colinear_segments(curve; generator_name = generator_name)
        else
            curve
        end
    end

    # Convert to InputOutputCurve, make convex, convert back
    io_curve = InputOutputCurve(curve)
    convex_io = increasing_curve_convex_approximation(
        io_curve;
        weights = weights,
        anchor = anchor,
        merge_colinear = false,
        generator_name = generator_name,
        _skip_validation = true,  # Already validated above
    )
    isnothing(convex_io) && return nothing

    @warn "Transformed non-convex AverageRateCurve to convex approximation$(gen_msg)"
    result = AverageRateCurve(convex_io)

    # Clean up any colinear segments (from original data or produced by convexification)
    return if merge_colinear
        merge_colinear_segments(result; generator_name = generator_name)
    else
        result
    end
end

# ProductionVariableCostCurve methods (CostCurve, FuelCurve)
# These delegate to the underlying ValueCurve and reconstruct the wrapper.
"""
    increasing_curve_convex_approximation(cost::CostCurve; kwargs...) -> Union{CostCurve, Nothing}

Transform the underlying `ValueCurve` of a `CostCurve` into a convex approximation.
Returns a new `CostCurve` with the convexified value curve, preserving `power_units` and `vom_cost`.
Returns `nothing` if data quality validation fails or curve is not strictly increasing.
"""
function increasing_curve_convex_approximation(cost::CostCurve; kwargs...)
    convex_vc = increasing_curve_convex_approximation(get_value_curve(cost); kwargs...)
    isnothing(convex_vc) && return nothing
    return CostCurve(convex_vc, get_power_units(cost), get_vom_cost(cost))
end

"""
    increasing_curve_convex_approximation(cost::FuelCurve; kwargs...) -> Union{FuelCurve, Nothing}

Transform the underlying `ValueCurve` of a `FuelCurve` into a convex approximation.
Returns a new `FuelCurve` with the convexified value curve, preserving all other fields.
Returns `nothing` if data quality validation fails or curve is not strictly increasing.
"""
function increasing_curve_convex_approximation(cost::FuelCurve; kwargs...)
    convex_vc = increasing_curve_convex_approximation(get_value_curve(cost); kwargs...)
    isnothing(convex_vc) && return nothing
    return FuelCurve(;
        value_curve = convex_vc,
        power_units = get_power_units(cost),
        fuel_cost = cost.fuel_cost,
        startup_fuel_offtake = cost.startup_fuel_offtake,
        vom_cost = get_vom_cost(cost),
    )
end

"""
    _reconstruct_points(original_points, new_slopes, anchor) -> Vector{XY_COORDS}

Reconstruct points from new slopes, preserving the anchor point.

After isotonic regression modifies the slopes, we need to reconstruct the y-coordinates.
The `anchor` parameter determines which point to preserve exactly:
- `:first` - preserve first point, propagate forward using new slopes
- `:last` - preserve last point, propagate backward using new slopes
- `:centroid` - minimize total vertical displacement from original points
"""
function _reconstruct_points(
    original_points::Vector{XY_COORDS},
    new_slopes::Vector{Float64},
    anchor::Symbol,
)
    n = length(original_points)

    if anchor === :first
        new_points = Vector{XY_COORDS}(undef, n)
        new_points[1] = original_points[1]
        for i in 2:n
            dx = original_points[i].x - original_points[i - 1].x
            new_y = new_points[i - 1].y + new_slopes[i - 1] * dx
            new_points[i] = (x = original_points[i].x, y = new_y)
        end

    elseif anchor === :last
        new_points = Vector{XY_COORDS}(undef, n)
        new_points[n] = original_points[n]
        for i in (n - 1):-1:1
            dx = original_points[i + 1].x - original_points[i].x
            new_y = new_points[i + 1].y - new_slopes[i] * dx
            new_points[i] = (x = original_points[i].x, y = new_y)
        end

    elseif anchor === :centroid
        forward_points = _reconstruct_points(original_points, new_slopes, :first)
        shift = 0.0
        for i in 1:n
            shift += original_points[i].y - forward_points[i].y
        end
        shift /= n
        new_points = XY_COORDS[(x = p.x, y = p.y + shift) for p in forward_points]
    else
        throw(ArgumentError("anchor must be :first, :last, or :centroid"))
    end

    return new_points
end

"""
    approximation_error(original, convexified; metric=:L2, weights=:length) -> Float64

Compute the error between original piecewise data and its convex approximation.

This is useful for assessing the quality of a convexification: a lower error means
the convex approximation is closer to the original non-convex curve.

Both arguments must have the same number of segments (same x-coordinates). When using
`increasing_curve_convex_approximation`, pass `merge_colinear=false` to preserve segment count for error computation.

# Arguments
- `original`: original `PiecewiseStepData` or `PiecewiseLinearData`
- `convexified`: the convex approximation (same type and same x-coordinates as original)
- `metric`: error metric to use
  - `:L2` (default): weighted root mean square error
  - `:L1`: weighted mean absolute error
  - `:Linf`: maximum absolute error (unweighted)
- `weights::Symbol`: weighting scheme for the error computation
  - `:length` (default): weight by segment x-extent
  - `:uniform`: equal weights for all segments

# Returns
The computed error as a `Float64`. Returns `0.0` if the curves are identical.
"""
function approximation_error end

function approximation_error(
    original::PiecewiseStepData,
    convexified::PiecewiseStepData;
    metric::Symbol = :L2,
    weights::Symbol = :length,
)
    y_orig = get_y_coords(original)
    y_convex = get_y_coords(convexified)
    length(y_orig) == length(y_convex) || throw(
        ArgumentError(
            "original and convexified must have the same number of segments " *
            "(got $(length(y_orig)) and $(length(y_convex))). " *
            "Use increasing_curve_convex_approximation with merge_colinear=false to preserve segment count.",
        ),
    )
    w = _compute_convex_weights(get_x_coords(original), weights)

    diff = y_orig .- y_convex

    if metric === :L2
        return norm(sqrt.(w) .* diff) / sqrt(sum(w))
    elseif metric === :L1
        return dot(w, abs.(diff)) / sum(w)
    elseif metric === :Linf
        return norm(diff, Inf)
    else
        throw(ArgumentError("metric must be :L2, :L1, or :Linf"))
    end
end

function approximation_error(
    original::PiecewiseLinearData,
    convexified::PiecewiseLinearData;
    metric::Symbol = :L2,
    weights::Symbol = :length,
)
    # For PiecewiseLinearData, compare slopes since that's what convexification modifies
    slopes_orig = get_slopes(original)
    slopes_convex = get_slopes(convexified)
    length(slopes_orig) == length(slopes_convex) || throw(
        ArgumentError(
            "original and convexified must have the same number of segments " *
            "(got $(length(slopes_orig)) and $(length(slopes_convex))). " *
            "Use increasing_curve_convex_approximation with merge_colinear=false to preserve segment count.",
        ),
    )
    w = _compute_convex_weights(get_x_coords(original), weights)

    diff = slopes_orig .- slopes_convex

    if metric === :L2
        return norm(sqrt.(w) .* diff) / sqrt(sum(w))
    elseif metric === :L1
        return dot(w, abs.(diff)) / sum(w)
    elseif metric === :Linf
        return norm(diff, Inf)
    else
        throw(ArgumentError("metric must be :L2, :L1, or :Linf"))
    end
end
