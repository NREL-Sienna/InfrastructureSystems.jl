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

function _slope_concavity_check(slopes::Vector{Float64})
    has_concavity = false
    for ix in 1:(length(slopes) - 1)
        if slopes[ix] < slopes[ix + 1] - _SLOPE_COMPARISON_ATOL
            @debug slopes
            return false
        end
        if slopes[ix] > slopes[ix + 1] + _SLOPE_COMPARISON_ATOL
            has_concavity = true
        end
    end
    return has_concavity
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

is_convex(fd::QuadraticFunctionData) = get_quadratic_term(fd) >= -_SLOPE_COMPARISON_ATOL

is_convex(pwl::PiecewiseLinearData) =
    _slope_convexity_check(get_slopes(pwl))

is_convex(pwl::PiecewiseStepData) =
    _slope_convexity_check(get_y_coords(pwl))


"""
    is_concave(data::FunctionData) -> Bool

Returns `true` if the function data represents a concave function, `false` otherwise.
Linear functions are NOT considered concave in this context (strict concavity or non-linear concavity).

- `LinearFunctionData`: Always returns `false`
- `QuadraticFunctionData`: Returns `true` if quadratic_term < 0
- `PiecewiseLinearData`: Returns `true` if slopes are non-increasing AND not all equal
- `PiecewiseStepData`: Returns `true` if y-coordinates are non-increasing AND not all equal
"""
is_concave(::LinearFunctionData) = false

is_concave(fd::QuadraticFunctionData) = get_quadratic_term(fd) < -_SLOPE_COMPARISON_ATOL

is_concave(pwl::PiecewiseLinearData) =
    _slope_concavity_check(get_slopes(pwl))

is_concave(pwl::PiecewiseStepData) =
    _slope_concavity_check(get_y_coords(pwl))
