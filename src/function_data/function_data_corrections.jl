"""
    make_convex(data::PiecewiseStepData; weights=:length) -> PiecewiseStepData

Return the closest convex approximation of `data` using isotonic regression (PAVA).

A convex piecewise step function has non-decreasing y-coordinates (which represent
slopes when used as the derivative of a piecewise linear function).

# Arguments
- `data::PiecewiseStepData`: the input step data
- `weights`: weighting scheme for regression
  - `:uniform` - all segments weighted equally
  - `:length` - segments weighted by their x-length (default, recommended)
  - `Vector{Float64}` - custom weights

# Returns
A new `PiecewiseStepData` that is convex (has non-decreasing y-coordinates).
Returns the input unchanged if already convex.
"""
function make_convex(data::PiecewiseStepData; weights = :length)
    is_convex(data) && return data

    y_coords = get_y_coords(data)
    x_coords = get_x_coords(data)

    # Compute weights
    w = _compute_convex_weights(x_coords, weights)

    # Apply isotonic regression to get non-decreasing values
    new_y_coords = isotonic_regression(y_coords, w)

    return PiecewiseStepData(x_coords, new_y_coords)
end

"""
Reconstruct PiecewiseLinearData points from corrected slopes.

# Arguments
- `original_points`: original points from the PiecewiseLinearData
- `new_slopes`: corrected slopes from isotonic regression
- `anchor`: which point to preserve exactly
  - `:first` - preserve first point, adjust all others (default)
  - `:last` - preserve last point, adjust backwards
  - `:centroid` - minimize total vertical displacement
"""
function _reconstruct_points(
    original_points::Vector{XY_COORDS},
    new_slopes::Vector{Float64},
    anchor::Symbol,
)
    n = length(original_points)
    x_coords = [p.x for p in original_points]

    if anchor === :first
        # Forward reconstruction from first point
        new_points = Vector{XY_COORDS}(undef, n)
        new_points[1] = original_points[1]
        for i in 2:n
            dx = x_coords[i] - x_coords[i - 1]
            new_y = new_points[i - 1].y + new_slopes[i - 1] * dx
            new_points[i] = (x = x_coords[i], y = new_y)
        end

    elseif anchor === :last
        # Backward reconstruction from last point
        new_points = Vector{XY_COORDS}(undef, n)
        new_points[n] = original_points[n]
        for i in (n - 1):-1:1
            dx = x_coords[i + 1] - x_coords[i]
            new_y = new_points[i + 1].y - new_slopes[i] * dx
            new_points[i] = (x = x_coords[i], y = new_y)
        end

    elseif anchor === :centroid
        # Minimize total squared vertical displacement
        # First compute with anchor=:first
        forward_points = _reconstruct_points(original_points, new_slopes, :first)

        # Compute optimal vertical shift
        original_y = [p.y for p in original_points]
        forward_y = [p.y for p in forward_points]
        shift = sum(original_y .- forward_y) / n

        new_points = XY_COORDS[(x = p.x, y = p.y + shift) for p in forward_points]
    else
        throw(ArgumentError("anchor must be :first, :last, or :centroid"))
    end

    return new_points
end

"""
    make_convex(data::PiecewiseLinearData; weights=:length, anchor=:first) -> PiecewiseLinearData

Return the closest convex approximation of `data` using isotonic regression (PAVA).

A convex piecewise linear function has non-decreasing slopes.

# Arguments
- `data::PiecewiseLinearData`: the input piecewise linear data
- `weights`: weighting scheme for regression
  - `:uniform` - all segments weighted equally
  - `:length` - segments weighted by their x-length (default, recommended)
  - `Vector{Float64}` - custom weights
- `anchor`: which point to preserve exactly when reconstructing
  - `:first` - preserve first point, adjust all others (default)
  - `:last` - preserve last point, adjust backwards
  - `:centroid` - minimize total vertical displacement

# Returns
A new `PiecewiseLinearData` that is convex (has non-decreasing slopes).
Returns the input unchanged if already convex.
"""
function make_convex(data::PiecewiseLinearData; weights = :length, anchor = :first)
    is_convex(data) && return data

    points = get_points(data)
    x_coords = get_x_coords(data)
    slopes = get_slopes(data)

    # Compute weights
    w = _compute_convex_weights(x_coords, weights)

    # Apply isotonic regression to slopes
    new_slopes = isotonic_regression(slopes, w)

    # Reconstruct points from corrected slopes
    new_points = _reconstruct_points(points, new_slopes, anchor)

    return PiecewiseLinearData(new_points)
end
