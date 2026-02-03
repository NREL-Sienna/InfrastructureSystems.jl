# CONVEXITY CHECKING UTILITIES
# Functions for analyzing convexity properties of FunctionData and ValueCurve types.

const _SLOPE_COMPARISON_ATOL = 1e-10

# ============================================================================
# DATA QUALITY VALIDATION
# Functions for detecting fundamentally invalid curve data.
# ============================================================================

# Configurable thresholds for data quality checks
const _MAX_REASONABLE_SLOPE = 1e8      # Maximum reasonable slope ($/MWh or similar units)
const _MAX_REASONABLE_COST = 1e10      # Maximum reasonable cost value
const _MIN_REASONABLE_COST = -1e6      # Allow small negative costs for edge cases, but flag large negatives

"""
    is_valid_data(data::FunctionData) -> Bool
    is_valid_data(curve::ValueCurve) -> Bool

Check if the function data or curve is valid and suitable for convexification.
Returns `true` if data is valid, `false` otherwise.

This validation should be called before attempting to convexify curves, as some data
is not just non-convex but fundamentally wrong (e.g., unrealistic or inconsistent values).

When validation fails, an error is logged with details about the specific issue.

# Quality Checks
- **X-coordinates ordering**: Must be strictly ascending
- **Negative slopes**: Cost curves should have non-negative marginal costs
- **Excessive slopes**: Unreasonably large slopes may indicate unit conversion errors
- **Negative costs**: Production costs should generally be non-negative
- **Excessive magnitudes**: Very large values may indicate wrong units or data errors
"""
function is_valid_data end

# LinearFunctionData - check proportional term (slope) and constant term
function is_valid_data(fd::LinearFunctionData)
    slope = get_proportional_term(fd)
    constant = get_constant_term(fd)

    if slope < -_SLOPE_COMPARISON_ATOL
        @error "Data quality issue: negative slope detected" slope curve_type = typeof(fd)
        return false
    end

    if abs(slope) > _MAX_REASONABLE_SLOPE
        @error "Data quality issue: unreasonably large slope detected" slope max_allowed =
            _MAX_REASONABLE_SLOPE curve_type = typeof(fd)
        return false
    end

    if constant < _MIN_REASONABLE_COST
        @error "Data quality issue: negative cost detected" constant curve_type = typeof(fd)
        return false
    end

    if abs(constant) > _MAX_REASONABLE_COST
        @error "Data quality issue: unreasonable cost magnitude detected" constant max_allowed =
            _MAX_REASONABLE_COST curve_type = typeof(fd)
        return false
    end

    return true
end

# QuadraticFunctionData - check quadratic term, proportional term, and constant
function is_valid_data(fd::QuadraticFunctionData)
    quadratic = get_quadratic_term(fd)
    proportional = get_proportional_term(fd)
    constant = get_constant_term(fd)

    # For quadratic cost functions, we primarily care about the initial slope (proportional term)
    if proportional < -_SLOPE_COMPARISON_ATOL
        @error "Data quality issue: negative initial slope detected" proportional_term =
            proportional curve_type = typeof(fd)
        return false
    end

    # Check for excessive quadratic term (translates to very steep curves)
    if abs(quadratic) > _MAX_REASONABLE_SLOPE
        @error "Data quality issue: unreasonably large quadratic term detected" quadratic max_allowed =
            _MAX_REASONABLE_SLOPE curve_type = typeof(fd)
        return false
    end

    if constant < _MIN_REASONABLE_COST
        @error "Data quality issue: negative constant cost detected" constant curve_type =
            typeof(fd)
        return false
    end

    if abs(constant) > _MAX_REASONABLE_COST
        @error "Data quality issue: unreasonable cost magnitude detected" constant max_allowed =
            _MAX_REASONABLE_COST curve_type = typeof(fd)
        return false
    end

    return true
end

# Helper to check x-coordinates are strictly ascending
function _check_x_coords_ascending(x_coords::Vector{Float64}, curve_type::Type)
    for i in 1:(length(x_coords) - 1)
        if x_coords[i] >= x_coords[i + 1]
            @error "Data quality issue: x-coordinates not in ascending order" x_i =
                x_coords[i] x_next = x_coords[i + 1] index = i curve_type
            return false
        end
    end
    return true
end

# PiecewiseLinearData - check x-coords ordering, slopes, and y-values
function is_valid_data(fd::PiecewiseLinearData)
    x_coords = get_x_coords(fd)
    slopes = get_slopes(fd)
    y_coords = get_y_coords(fd)

    # Check x-coordinates are ascending
    if !_check_x_coords_ascending(x_coords, typeof(fd))
        return false
    end

    # Check for negative slopes
    for (i, slope) in enumerate(slopes)
        if slope < -_SLOPE_COMPARISON_ATOL
            @error "Data quality issue: negative slope detected in segment $i" slope segment =
                i curve_type = typeof(fd)
            return false
        end
    end

    # Check for excessive slopes
    for (i, slope) in enumerate(slopes)
        if abs(slope) > _MAX_REASONABLE_SLOPE
            @error "Data quality issue: unreasonably large slope detected in segment $i" slope max_allowed =
                _MAX_REASONABLE_SLOPE segment = i curve_type = typeof(fd)
            return false
        end
    end

    # Check for negative costs (y-values)
    for (i, y) in enumerate(y_coords)
        if y < _MIN_REASONABLE_COST
            @error "Data quality issue: negative cost detected at point $i" cost = y point =
                i curve_type = typeof(fd)
            return false
        end
    end

    # Check for excessive cost magnitudes
    for (i, y) in enumerate(y_coords)
        if abs(y) > _MAX_REASONABLE_COST
            @error "Data quality issue: unreasonable cost magnitude at point $i" cost =
                y max_allowed = _MAX_REASONABLE_COST point = i curve_type = typeof(fd)
            return false
        end
    end

    return true
end

# PiecewiseStepData - y-coords are slopes/rates
function is_valid_data(fd::PiecewiseStepData)
    x_coords = get_x_coords(fd)
    y_coords = get_y_coords(fd)  # These are marginal rates/slopes

    # Check x-coordinates are ascending
    if !_check_x_coords_ascending(x_coords, typeof(fd))
        return false
    end

    # Check for negative slopes
    for (i, slope) in enumerate(y_coords)
        if slope < -_SLOPE_COMPARISON_ATOL
            @error "Data quality issue: negative marginal rate detected in segment $i" rate =
                slope segment = i curve_type = typeof(fd)
            return false
        end
    end

    # Check for excessive slopes
    for (i, slope) in enumerate(y_coords)
        if abs(slope) > _MAX_REASONABLE_SLOPE
            @error "Data quality issue: unreasonably large marginal rate in segment $i" rate =
                slope max_allowed = _MAX_REASONABLE_SLOPE segment = i curve_type = typeof(fd)
            return false
        end
    end

    return true
end

"""
    is_valid_data(curve::ValueCurve) -> Bool

Check if a ValueCurve has valid data suitable for convexification.

For `InputOutputCurve` and `IncrementalCurve`, delegates to the underlying FunctionData check.
For `AverageRateCurve`, converts to `InputOutputCurve` first since average rates are NOT 
the same as slopes - the actual slopes must be validated.
"""
is_valid_data(curve::InputOutputCurve) = is_valid_data(get_function_data(curve))
is_valid_data(curve::IncrementalCurve) = is_valid_data(get_function_data(curve))

# AverageRateCurve: average rates != slopes, so convert to get actual slope information
function is_valid_data(curve::AverageRateCurve)
    # Convert to InputOutputCurve to get actual cost values and slopes
    io_curve = InputOutputCurve(curve)
    return is_valid_data(io_curve)
end

# Fallback
is_valid_data(data) = throw(NotImplementedError("is_valid_data", typeof(data)))

# ============================================================================
# CONVEXITY CHECKING
# ============================================================================

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
    for ix in 1:(length(slopes) - 1)
        if slopes[ix] < slopes[ix + 1] - _SLOPE_COMPARISON_ATOL
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
    is_concave(data::FunctionData) -> Bool

Returns `true` if the function data is concave, `false` otherwise.
Linear functions (straight lines) are considered concave.

- `LinearFunctionData`: Always returns `true`
- `QuadraticFunctionData`: Returns `true` if quadratic_term ≤ 0
- `PiecewiseLinearData`: Returns `true` if slopes are non-increasing
- `PiecewiseStepData`: Returns `true` if y-coordinates are non-increasing
"""
is_concave(::LinearFunctionData) = true

is_concave(f::QuadraticFunctionData) = get_quadratic_term(f) <= 0.0

is_concave(pwl::PiecewiseLinearData) =
    _slope_concavity_check(get_slopes(pwl))

is_concave(pwl::PiecewiseStepData) =
    _slope_concavity_check(get_y_coords(pwl))

"""
    is_convex(curve::ValueCurve) -> Bool

Check if a `ValueCurve` is convex.

- `InputOutputCurve` (including `LinearCurve`, `QuadraticCurve`, `PiecewisePointCurve`): 
  Delegates to convexity check of the underlying `FunctionData`.
- `IncrementalCurve` (including `PiecewiseIncrementalCurve`): Delegates to convexity check 
  of the underlying `FunctionData`. This works because for `IncrementalCurve`, the 
  `FunctionData` y-coordinates represent marginal rates (slopes), so checking if they are 
  non-decreasing is equivalent to checking convexity of the original curve.
- `AverageRateCurve` (including `PiecewiseAverageCurve`): Converts to `InputOutputCurve` 
  first, then checks. This is necessary because average rates are NOT the same as slopes; 
  non-decreasing average rates do not imply convexity.
"""
is_convex(curve::InputOutputCurve) = is_convex(get_function_data(curve))
is_convex(curve::IncrementalCurve) = is_convex(get_function_data(curve))
is_convex(curve::AverageRateCurve) = is_convex(InputOutputCurve(curve))

# Fallback method for unsupported types
is_convex(data) = throw(NotImplementedError("is_convex", typeof(data)))

"""
    is_concave(curve::ValueCurve) -> Bool

Check if a `ValueCurve` is concave.

- `InputOutputCurve` (including `LinearCurve`, `QuadraticCurve`, `PiecewisePointCurve`): 
  Delegates to concavity check of the underlying `FunctionData`.
- `IncrementalCurve` (including `PiecewiseIncrementalCurve`): Delegates to concavity check 
  of the underlying `FunctionData`. This works because for `IncrementalCurve`, the 
  `FunctionData` y-coordinates represent marginal rates (slopes), so checking if they are 
  non-increasing is equivalent to checking concavity of the original curve.
- `AverageRateCurve` (including `PiecewiseAverageCurve`): Converts to `InputOutputCurve` 
  first, then checks. This is necessary because average rates are NOT the same as slopes; 
  non-increasing average rates do not imply concavity.
"""
is_concave(curve::InputOutputCurve) = is_concave(get_function_data(curve))
is_concave(curve::IncrementalCurve) = is_concave(get_function_data(curve))
is_concave(curve::AverageRateCurve) = is_concave(InputOutputCurve(curve))

# Fallback method for unsupported types
is_concave(data) = throw(NotImplementedError("is_concave", typeof(data)))

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
