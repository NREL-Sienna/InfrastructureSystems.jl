"""
    make_convex(data::FunctionData; kwargs...) -> FunctionData
    make_convex(curve::ValueCurve; kwargs...) -> ValueCurve

Return a convex approximation of the input data or curve.

For `FunctionData` types:
- `LinearFunctionData`: Always convex, returns unchanged
- `QuadraticFunctionData`: Projects concave quadratics (a < 0) to linear by setting a = 0
- `PiecewiseStepData`: Uses isotonic regression (PAVA) on y-coordinates
- `PiecewiseLinearData`: Uses isotonic regression on slopes, then reconstructs points

For `ValueCurve` types:
- `InputOutputCurve`: Delegates to underlying `FunctionData` make_convex
- `IncrementalCurve`: Converts to `InputOutputCurve`, makes convex, converts back
- `AverageRateCurve`: Converts to `InputOutputCurve`, makes convex, converts back

All methods return the input unchanged if already convex.

# Keyword Arguments
- `weights`: Weighting scheme for regression (`:uniform`, `:length`, or custom `Vector{Float64}`)
- `anchor`: Point preservation strategy for reconstruction (`:first`, `:last`, `:centroid`)
"""
function make_convex end

make_convex(data::LinearFunctionData) = data

function make_convex(data::QuadraticFunctionData)
    is_convex(data) && return data
    return LinearFunctionData(get_proportional_term(data), get_constant_term(data))
end

function make_convex(data::PiecewiseStepData; weights = :length)
    is_convex(data) && return data

    y_coords = get_y_coords(data)
    x_coords = get_x_coords(data)
    w = _compute_convex_weights(x_coords, weights)
    new_y_coords = isotonic_regression(y_coords, w)

    return PiecewiseStepData(x_coords, new_y_coords)
end

function make_convex(data::PiecewiseLinearData; weights = :length, anchor = :first)
    is_convex(data) && return data

    points = get_points(data)
    x_coords = get_x_coords(data)
    slopes = get_slopes(data)
    w = _compute_convex_weights(x_coords, weights)
    new_slopes = isotonic_regression(slopes, w)
    new_points = _reconstruct_points(points, new_slopes, anchor)

    return PiecewiseLinearData(new_points)
end

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

make_convex(curve::InputOutputCurve{LinearFunctionData}) = curve

function make_convex(curve::InputOutputCurve{QuadraticFunctionData})
    is_convex(curve) && return curve
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
    new_fd = make_convex(get_function_data(curve); weights = weights, anchor = anchor)
    return InputOutputCurve(new_fd, get_input_at_zero(curve))
end

function make_convex(curve::IncrementalCurve{LinearFunctionData})
    is_convex(curve) && return curve
    io_curve = InputOutputCurve(curve)
    convex_io = make_convex(io_curve)
    return IncrementalCurve(convex_io)
end

function make_convex(curve::IncrementalCurve{PiecewiseStepData}; weights = :length)
    is_convex(curve) && return curve
    fd = get_function_data(curve)
    new_fd = make_convex(fd; weights = weights)
    return IncrementalCurve(new_fd, get_initial_input(curve), get_input_at_zero(curve))
end

function make_convex(curve::AverageRateCurve{LinearFunctionData})
    is_convex(curve) && return curve
    io_curve = InputOutputCurve(curve)
    convex_io = make_convex(io_curve)
    return AverageRateCurve(convex_io)
end

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
    is_convex(curve::ValueCurve) -> Bool

Check if a `ValueCurve` is convex.

For `InputOutputCurve`: delegates to underlying `FunctionData`
For `IncrementalCurve`: converts to `InputOutputCurve` (integrating via `running_sum`), then checks
For `AverageRateCurve`: converts to `InputOutputCurve`, then checks

Note: These methods must be defined here (after value_curve.jl is loaded) rather than in
convexity_checks.jl due to the include order.
"""
is_convex(curve::InputOutputCurve) = is_convex(get_function_data(curve))
is_convex(curve::IncrementalCurve) = is_convex(InputOutputCurve(curve))
is_convex(curve::AverageRateCurve) = is_convex(InputOutputCurve(curve))

@deprecate is_concave(curve::InputOutputCurve) !is_convex(curve)
@deprecate is_concave(curve::IncrementalCurve) !is_convex(curve)
@deprecate is_concave(curve::AverageRateCurve) !is_convex(curve)
