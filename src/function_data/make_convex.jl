# CONVEXITY ANALYSIS UTILITIES

"""
    convexity_violations(data::PiecewiseLinearData) -> Vector{Int}
    convexity_violations(data::PiecewiseStepData) -> Vector{Int}

Return indices where convexity is violated (where slope decreases).

For `PiecewiseLinearData`, returns indices `i` where `slope[i] > slope[i+1]`.
For `PiecewiseStepData`, returns indices `i` where `y[i] > y[i+1]`.
"""
function convexity_violations(data::PiecewiseLinearData)
    slopes = get_slopes(data)
    return findall(i -> slopes[i] > slopes[i + 1], 1:(length(slopes) - 1))
end

function convexity_violations(data::PiecewiseStepData)
    y = get_y_coords(data)
    return findall(i -> y[i] > y[i + 1], 1:(length(y) - 1))
end

"""
    convexity_gap(data::PiecewiseLinearData) -> Float64
    convexity_gap(data::PiecewiseStepData) -> Float64

Return the maximum convexity violation (maximum decrease in slope/value).
Returns 0.0 if already convex.

This measures the severity of the worst convexity violation.
"""
function convexity_gap(data::PiecewiseLinearData)
    slopes = get_slopes(data)
    max_gap = 0.0
    for i in 1:(length(slopes) - 1)
        gap = slopes[i] - slopes[i + 1]
        gap > max_gap && (max_gap = gap)
    end
    return max_gap
end

function convexity_gap(data::PiecewiseStepData)
    y = get_y_coords(data)
    max_gap = 0.0
    for i in 1:(length(y) - 1)
        gap = y[i] - y[i + 1]
        gap > max_gap && (max_gap = gap)
    end
    return max_gap
end

"""
    approximation_error(original, approximated; metric=:L2, weights=:length) -> Float64

Compute the error between original and approximated piecewise data.

# Arguments
- `original`: original PiecewiseStepData or PiecewiseLinearData
- `approximated`: approximated data (same type as original)
- `metric`: error metric
  - `:L2` - root mean square error (default)
  - `:L1` - mean absolute error
  - `:Linf` - maximum absolute error
- `weights`: weighting scheme (`:uniform`, `:length`, or custom)

# Returns
The computed error as a Float64.
"""
function approximation_error(
    original::PiecewiseStepData,
    approximated::PiecewiseStepData;
    metric::Symbol = :L2,
    weights = :length,
)
    y_orig = get_y_coords(original)
    y_approx = get_y_coords(approximated)
    w = _compute_convex_weights(get_x_coords(original), weights)

    diff = y_orig .- y_approx

    if metric === :L2
        # Weighted L2 norm (root mean square error)
        return norm(sqrt.(w) .* diff) / sqrt(sum(w))
    elseif metric === :L1
        # Weighted L1 norm (mean absolute error)
        return dot(w, abs.(diff)) / sum(w)
    elseif metric === :Linf
        # L∞ norm (maximum absolute error)
        return norm(diff, Inf)
    else
        throw(ArgumentError("metric must be :L2, :L1, or :Linf"))
    end
end

function approximation_error(
    original::PiecewiseLinearData,
    approximated::PiecewiseLinearData;
    metric::Symbol = :L2,
    weights = :length,
)
    # Compare based on slopes
    slopes_orig = get_slopes(original)
    slopes_approx = get_slopes(approximated)
    w = _compute_convex_weights(get_x_coords(original), weights)

    diff = slopes_orig .- slopes_approx

    if metric === :L2
        # Weighted L2 norm (root mean square error)
        return norm(sqrt.(w) .* diff) / sqrt(sum(w))
    elseif metric === :L1
        # Weighted L1 norm (mean absolute error)
        return dot(w, abs.(diff)) / sum(w)
    elseif metric === :Linf
        # L∞ norm (maximum absolute error)
        return norm(diff, Inf)
    else
        throw(ArgumentError("metric must be :L2, :L1, or :Linf"))
    end
end

const _SLOPE_COMPARISON_ATOL = 1e-10

function _slope_convexity_check(slopes::Vector{Float64})
    for ix in 1:(length(slopes) - 1)
        if slopes[ix] > slopes[ix + 1] + _SLOPE_COMPARISON_ATOL
            @debug slopes
            return false
        end
    end
    return true
end

"""
    is_convex(data::FunctionData) -> Bool

Returns `true` if the function data is convex, `false` otherwise.
Linear functions (straight lines) are considered convex.

- `LinearFunctionData`: Always returns `true`
- `QuadraticFunctionData`: Returns `true` if quadratic_term ≥ 0
- `PiecewiseLinearData`: Returns `true` if slopes are non-decreasing
- `PiecewiseStepData`: Returns `true` if y-coordinates are non-decreasing
"""
is_convex(::LinearFunctionData) = true

is_convex(f::QuadraticFunctionData) = get_quadratic_term(f) >= -_SLOPE_COMPARISON_ATOL

is_convex(pwl::PiecewiseLinearData) =
    _slope_convexity_check(get_slopes(pwl))

is_convex(pwl::PiecewiseStepData) =
    _slope_convexity_check(get_y_coords(pwl))

"""
    is_convex(curve::ValueCurve) -> Bool

Check if a `ValueCurve` is convex.

For `InputOutputCurve`: delegates to underlying `FunctionData`
For `IncrementalCurve`: converts to `InputOutputCurve` (integrating via `running_sum`), then checks
For `AverageRateCurve`: converts to `InputOutputCurve`, then checks
"""
is_convex(curve::InputOutputCurve) = is_convex(get_function_data(curve))
is_convex(curve::IncrementalCurve) = is_convex(InputOutputCurve(curve))
is_convex(curve::AverageRateCurve) = is_convex(InputOutputCurve(curve))

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
    # For concave quadratic (a < 0), project to linear by removing quadratic term
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

"""
Reconstruct points from new slopes, preserving the anchor point.
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
