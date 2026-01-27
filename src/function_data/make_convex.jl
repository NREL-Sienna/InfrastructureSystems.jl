# CONVEX APPROXIMATION UTILITIES
# Functions for transforming non-convex curves into convex approximations.

"""
    make_convex(curve::ValueCurve; kwargs...) -> ValueCurve

Transform a non-convex `ValueCurve` into a convex approximation using isotonic regression.

Returns the original curve unchanged if already convex.

# Supported curve types
- `InputOutputCurve{LinearFunctionData}`: Always convex, returned unchanged
- `InputOutputCurve{QuadraticFunctionData}`: Concave quadratics projected to linear (a=0)
- `InputOutputCurve{PiecewiseLinearData}`: Isotonic regression on slopes
- `IncrementalCurve{PiecewiseStepData}`: Converts to IO curve, makes convex, converts back
- `AverageRateCurve{PiecewiseStepData}`: Converts to IO curve, makes convex, converts back

Note: `IncrementalCurve{LinearFunctionData}` and `AverageRateCurve{LinearFunctionData}` are
intentionally NOT supported. These represent derivatives of quadratic functions and rarely
appear in real data. The arbitrary projection approach used for quadratics is not appropriate.

# Keyword Arguments
- `weights`: Weighting scheme for isotonic regression (affects how violations are resolved)
  - `:length` (default): weight segments by x-extent (wider segments have more influence)
  - `:uniform`: all segments equally weighted
  - `Vector{Float64}`: custom weights per segment
- `anchor`: Point preservation strategy for reconstructing points from new slopes
  - `:first` (default): preserve first point, propagate forward
  - `:last`: preserve last point, propagate backward
  - `:centroid`: minimize total vertical displacement
"""
function make_convex end

# InputOutputCurve methods
make_convex(curve::InputOutputCurve{LinearFunctionData}) = curve

function make_convex(curve::InputOutputCurve{QuadraticFunctionData})
    is_convex(curve) && return curve
    # For concave quadratic (a < 0), project to linear by removing quadratic term.
    # Not the best approximation but simple and effective, given the very limited use case.
    fd = get_function_data(curve)
    new_fd = LinearFunctionData(get_proportional_term(fd), get_constant_term(fd))
    return InputOutputCurve(new_fd, get_input_at_zero(curve))
end

function make_convex(
    curve::InputOutputCurve{PiecewiseLinearData};
    weights = :length,
    anchor = :first,
)
    is_convex(curve) && return curve
    fd = get_function_data(curve)
    points = get_points(fd)
    x_coords = get_x_coords(fd)
    slopes = get_slopes(fd)

    w = _compute_convex_weights(x_coords, weights)
    new_slopes = isotonic_regression(slopes, w)
    new_points = _reconstruct_points(points, new_slopes, anchor)

    return InputOutputCurve(PiecewiseLinearData(new_points), get_input_at_zero(curve))
end

# IncrementalCurve methods
# Note: make_convex is NOT defined for IncrementalCurve{LinearFunctionData}.
# Such a curve represents the derivative of a quadratic IO curve: f'(x) = ax + b.
# For concave quadratics (a < 0), we would project to linear by removing the quadratic term,
# but this approach is arbitrary and not a proper convex approximation.
# These curve types rarely appear in real data (most cost curves are piecewise from measured data).

function make_convex(
    curve::IncrementalCurve{PiecewiseStepData};
    weights = :length,
    anchor = :first,
)
    is_convex(curve) && return curve
    io_curve = InputOutputCurve(curve)
    convex_io = make_convex(io_curve; weights = weights, anchor = anchor)
    return IncrementalCurve(convex_io)
end

# AverageRateCurve methods
# Note: make_convex is NOT defined for AverageRateCurve{LinearFunctionData}.
# Such a curve represents f(x)/x where f is quadratic. For concave cases,
# the same concerns apply as for IncrementalCurve{LinearFunctionData} above.

function make_convex(
    curve::AverageRateCurve{PiecewiseStepData};
    weights = :length,
    anchor = :first,
)
    is_convex(curve) && return curve
    io_curve = InputOutputCurve(curve)
    convex_io = make_convex(io_curve; weights = weights, anchor = anchor)
    return AverageRateCurve(convex_io)
end

# ProductionVariableCostCurve methods (CostCurve, FuelCurve)
# These delegate to the underlying ValueCurve and reconstruct the wrapper.

"""
    make_convex(cost::CostCurve; kwargs...) -> CostCurve

Transform the underlying `ValueCurve` of a `CostCurve` into a convex approximation.
Returns a new `CostCurve` with the convexified value curve, preserving `power_units` and `vom_cost`.
"""
function make_convex(cost::CostCurve; kwargs...)
    convex_vc = make_convex(get_value_curve(cost); kwargs...)
    return CostCurve(convex_vc, get_power_units(cost), get_vom_cost(cost))
end

"""
    make_convex(cost::FuelCurve; kwargs...) -> FuelCurve

Transform the underlying `ValueCurve` of a `FuelCurve` into a convex approximation.
Returns a new `FuelCurve` with the convexified value curve, preserving all other fields.
"""
function make_convex(cost::FuelCurve; kwargs...)
    convex_vc = make_convex(get_value_curve(cost); kwargs...)
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

# Arguments
- `original`: original `PiecewiseStepData` or `PiecewiseLinearData`
- `convexified`: the convex approximation (same type as original)
- `metric`: error metric to use
  - `:L2` (default): weighted root mean square error
  - `:L1`: weighted mean absolute error  
  - `:Linf`: maximum absolute error (unweighted)
- `weights`: weighting scheme for the error computation
  - `:length` (default): weight by segment x-extent
  - `:uniform`: equal weights for all segments
  - `Vector{Float64}`: custom weights

# Returns
The computed error as a `Float64`. Returns `0.0` if the curves are identical.

# Example
```julia
curve = InputOutputCurve(piecewise_data)
convex_curve = make_convex(curve)
error = approximation_error(
    get_function_data(curve),
    get_function_data(convex_curve)
)
```
"""
function approximation_error(
    original::PiecewiseStepData,
    convexified::PiecewiseStepData;
    metric::Symbol = :L2,
    weights = :length,
)
    y_orig = get_y_coords(original)
    y_convex = get_y_coords(convexified)
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
    weights = :length,
)
    # For PiecewiseLinearData, compare slopes since that's what convexification modifies
    slopes_orig = get_slopes(original)
    slopes_convex = get_slopes(convexified)
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
