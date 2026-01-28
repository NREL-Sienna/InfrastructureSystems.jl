# CONVEXITY CHECKING UTILITIES
# Functions for analyzing convexity properties of FunctionData and ValueCurve types.

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

- `LinearCurve`: Always returns `true`
- `QuadraticCurve`: Returns `true` if quadratic_term ≥ 0
- `PiecewisePointCurve`: Returns `true` if slopes are non-decreasing
- `PiecewiseIncrementalCurve`: Returns `true` if y-coordinates are non-decreasing
- `PiecewiseAverageCurve`: Converts to `InputOutputCurve`, then checks
"""
is_convex(curve::LinearCurve) = is_convex(get_function_data(curve))
is_convex(curve::QuadraticCurve) = is_convex(get_function_data(curve))
is_convex(curve::PiecewisePointCurve) = is_convex(get_function_data(curve))
is_convex(curve::PiecewiseIncrementalCurve) = is_convex(get_function_data(curve))
is_convex(curve::PiecewiseAverageCurve) = is_convex(InputOutputCurve(curve))

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
