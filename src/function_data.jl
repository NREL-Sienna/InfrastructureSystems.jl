abstract type FunctionData end

"""
Structure to represent the underlying data of linear functions. Principally used for
the representation of cost functions `f(x) = proportional_term*x + constant_term`.

# Arguments
 - `proportional_term::Float64`: the proportional term in the represented function
 - `constant_term::Float64`: the constant term in the represented function
"""
@kwdef struct LinearFunctionData <: FunctionData
    proportional_term::Float64
    constant_term::Float64
end

LinearFunctionData(proportional_term) = LinearFunctionData(proportional_term, 0.0)

get_proportional_term(fd::LinearFunctionData) = fd.proportional_term
get_constant_term(fd::LinearFunctionData) = fd.constant_term

function _transform_linear_vector_for_hdf(data::Vector{LinearFunctionData})
    transfd_data = Vector{NTuple{2, Float64}}(undef, length(data))
    for (ix, fd) in enumerate(data)
        transfd_data[ix] = (get_proportional_term(fd), get_constant_term(fd))
    end
    return transfd_data
end

function transform_array_for_hdf(data::Vector{LinearFunctionData})
    return transform_array_for_hdf(_transform_linear_vector_for_hdf(data))
end

function transform_array_for_hdf(
    data::SortedDict{Dates.DateTime, Vector{LinearFunctionData}},
)
    transfd_data =
        sizehint!(SortedDict{Dates.DateTime, Vector{NTuple{2, Float64}}}(), length(data))
    for (k, fd) in data
        transfd_data[k] = _transform_linear_vector_for_hdf(fd)
    end
    return transform_array_for_hdf(transfd_data)
end

function Base.show(io::IO, ::MIME"text/plain", fd::LinearFunctionData)
    get(io, :compact, false)::Bool || print(io, "$(typeof(fd)) representing function ")
    print(io, "f(x) = $(fd.proportional_term) x + $(fd.constant_term)")
end

"""
Structure to represent the underlying data of quadratic functions. Principally used for the
representation of cost functions
`f(x) = quadratic_term*x^2 + proportional_term*x + constant_term`.

# Arguments
 - `quadratic_term::Float64`: the quadratic term in the represented function
 - `proportional_term::Float64`: the proportional term in the represented function
 - `constant_term::Float64`: the constant term in the represented function
"""
@kwdef struct QuadraticFunctionData <: FunctionData
    quadratic_term::Float64
    proportional_term::Float64
    constant_term::Float64
end

get_quadratic_term(fd::QuadraticFunctionData) = fd.quadratic_term
get_proportional_term(fd::QuadraticFunctionData) = fd.proportional_term
get_constant_term(fd::QuadraticFunctionData) = fd.constant_term

function _transform_quadratic_vector_for_hdf(data::Vector{QuadraticFunctionData})
    transfd_data = Vector{NTuple{3, Float64}}(undef, length(data))
    for (ix, fd) in enumerate(data)
        transfd_data[ix] =
            (get_quadratic_term(fd), get_proportional_term(fd), get_constant_term(fd))
    end
    return transfd_data
end

function transform_array_for_hdf(data::Vector{QuadraticFunctionData})
    return transform_array_for_hdf(_transform_quadratic_vector_for_hdf(data))
end

function transform_array_for_hdf(
    data::SortedDict{Dates.DateTime, Vector{QuadraticFunctionData}},
)
    transfd_data =
        sizehint!(SortedDict{Dates.DateTime, Vector{NTuple{3, Float64}}}(), length(data))
    for (k, fd) in data
        transfd_data[k] = _transform_quadratic_vector_for_hdf(fd)
    end
    return transform_array_for_hdf(transfd_data)
end

function _validate_piecewise_x(x_coords::Vector)
    (length(x_coords) < 2) &&
        throw(ArgumentError("Must specify at least two x-coordinates"))
    # This could be generalized to allow NaNs in more places
    if !(issorted(x_coords) || (isnan(first(x_coords)) && issorted(x_coords[2:end])))
        throw(ArgumentError("Piecewise x-coordinates must be ascending, got $x_coords"))
    end
end

function Base.show(io::IO, ::MIME"text/plain", fd::QuadraticFunctionData)
    get(io, :compact, false)::Bool || print(io, "$(typeof(fd)) representing function ")
    print(
        io,
        "f(x) = $(fd.quadratic_term) x^2 + $(fd.proportional_term) x + $(fd.constant_term)",
    )
end

"""
Structure to represent piecewise linear data as a series of points: two points define one
segment, three points define two segments, etc. The curve starts at the first point given,
not the origin. Principally used for the representation of cost functions where the points
store quantities (x, y), such as (MW, \$/h).

# Arguments
 - `points::Vector{@NamedTuple{x::Float64, y::Float64}}`: the points that define the function
"""
@kwdef struct PiecewiseLinearData <: FunctionData
    points::Vector{XY_COORDS}

    function PiecewiseLinearData(points::Vector{<:NamedTuple{(:x, :y)}})
        _validate_piecewise_x(first.(points))
        return new(points)
    end
end

function PiecewiseLinearData(points::Vector{<:NamedTuple})
    throw(
        ArgumentError(
            "If constructing PiecewiseLinearData with NamedTuples, points must have type Vector{<:NamedTuple{(:x, :y)}}; got $(typeof(points))",
        ),
    )
end

function _convert_to_xy_coords(point)
    # Need to be able to handle dicts for deserialization
    if point isa AbstractDict
        (keys(point) == Set(["x", "y"])) && return (x = point["x"], y = point["y"])
        throw(
            ArgumentError(
                "If constructing PiecewiseLinearData with dictionaries, keys must be [\"x\", \"y\"]; got $(collect(keys(point)))",
            ),
        )
    end
    return NamedTuple{(:x, :y)}(point)
end

function PiecewiseLinearData(points::AbstractVector)
    PiecewiseLinearData(_convert_to_xy_coords.(points))
end

"Get the points that define the piecewise data"
get_points(data::PiecewiseLinearData) = data.points

"Get the x-coordinates of the points that define the piecewise data"
get_x_coords(data::PiecewiseLinearData) = [p.x for p in get_points(data)]

"Get the y-coordinates of the points that define the PiecewiseLinearData"
get_y_coords(data::PiecewiseLinearData) = [p.y for p in get_points(data)]

function _get_slopes(vc::Vector{XY_COORDS})
    slopes = Vector{Float64}(undef, length(vc) - 1)
    (prev_x, prev_y) = vc[1]
    for (i, (comp_x, comp_y)) in enumerate(vc[2:end])
        slopes[i] = (comp_y - prev_y) / (comp_x - prev_x)
        (prev_x, prev_y) = (comp_x, comp_y)
    end
    return slopes
end

_get_x_lengths(x_coords) = x_coords[2:end] .- x_coords[1:(end - 1)]

"""
Calculates the slopes of the line segments defined by the PiecewiseLinearData,
returning one fewer slope than the number of underlying points.
"""
function get_slopes(pwl::PiecewiseLinearData)
    return _get_slopes(get_points(pwl))
end

function _transform_pwl_linear_vector_for_hdf(data::Vector{PiecewiseLinearData})
    transfd_data = Vector{Vector{NTuple{2, Float64}}}(undef, length(data))
    for (ix, fd) in enumerate(data)
        transfd_data[ix] = NTuple{2, Float64}.(get_points(fd))
    end
    return transfd_data
end

function transform_array_for_hdf(data::Vector{PiecewiseLinearData})
    return transform_array_for_hdf(_transform_pwl_linear_vector_for_hdf(data))
end

function transform_array_for_hdf(
    data::SortedDict{Dates.DateTime, Vector{PiecewiseLinearData}},
)
    transfd_data = sizehint!(
        SortedDict{Dates.DateTime, Vector{Vector{Tuple{Float64, Float64}}}}(),
        length(data),
    )
    for (k, fd) in data
        transfd_data[k] = _transform_pwl_linear_vector_for_hdf(fd)
    end
    return transform_array_for_hdf(transfd_data)
end

function Base.show(io::IO, ::MIME"text/plain", fd::PiecewiseLinearData)
    if get(io, :compact, false)::Bool
        print(io, "piecewise linear ")
    else
        print(io, "$(typeof(fd)) representing piecewise linear function ")
    end
    print(io, "y = f(x) connecting points:")
    for point in fd.points
        print(io, "\n  $point")
    end
end

"""
Structure to represent a step function as a series of endpoint x-coordinates and segment
y-coordinates: two x-coordinates and one y-coordinate defines a single segment, three
x-coordinates and two y-coordinates define two segments, etc. This can be useful to
represent the derivative of a [PiecewiseLinearData](@ref), where the y-coordinates of this
step function represent the slopes of that piecewise linear function, so there is also an
optional field `c` that can be used to store the initial y-value of that piecewise linear
function. Principally used for the representation of cost functions where the points store
quantities (x, dy/dx), such as (MW, \$/MWh).

# Arguments
 - `x_coords::Vector{Float64}`: the x-coordinates of the endpoints of the segments
 - `y_coords::Vector{Float64}`: the y-coordinates of the segments: `y_coords[1]` is the y-value between
 `x_coords[1]` and `x_coords[2]`, etc. Must have one fewer elements than `x_coords`.
 - `c::Union{Nothing, Float64}`: optional, the value to use for the integral from 0 to `x_coords[1]` of this function
"""
@kwdef struct PiecewiseStepData <: FunctionData
    x_coords::Vector{Float64}
    y_coords::Vector{Float64}

    function PiecewiseStepData(x_coords, y_coords)
        if length(y_coords) == length(x_coords)
            # To make the lengths match for HDF serialization, we prepend NaN to y_coords
            isnan(first(y_coords)) && return PiecewiseStepData(x_coords, y_coords[2:end])
            # To leave x_coords[1] undefined, must explicitly pass in NaN
        end
        _validate_piecewise_x(x_coords)
        (length(y_coords) != length(x_coords) - 1) &&
            throw(ArgumentError("Must specify one fewer y-coordinates than x-coordinates"))
        return new(x_coords, y_coords)
    end
end

# For HDF deserialization
PiecewiseStepData(data::AbstractMatrix) = PiecewiseStepData(data[:, 1], data[:, 2])

"Get the x-coordinates of the points that define the piecewise data"
get_x_coords(data::PiecewiseStepData) = data.x_coords

"Get the y-coordinates of the segments in the PiecewiseStepData"
get_y_coords(data::PiecewiseStepData) = data.y_coords

function running_sum(data::PiecewiseStepData)
    slopes = get_y_coords(data)
    x_coords = get_x_coords(data)
    points = Vector{XY_COORDS}(undef, length(x_coords))
    running_y = 0
    points[1] = (x = x_coords[1], y = running_y)
    for (i, (prev_slope, this_x, dx)) in
        enumerate(zip(slopes, x_coords[2:end], get_x_lengths(data)))
        running_y += prev_slope * dx
        points[i + 1] = (x = this_x, y = running_y)
    end
    return points
end

function _transform_pwl_step_vector_hdf(data::Vector{PiecewiseStepData})
    transfd_data = Vector{Matrix{Float64}}(undef, length(data))
    for (ix, fd) in enumerate(data)
        x_coords = get_x_coords(fd)
        y_coords = vcat(NaN, get_y_coords(fd))
        transfd_data[ix] = hcat(x_coords, y_coords)
    end
    return transfd_data
end

function transform_array_for_hdf(data::Vector{PiecewiseStepData})
    return transform_array_for_hdf(_transform_pwl_step_vector_hdf(data))
end

function transform_array_for_hdf(
    data::SortedDict{Dates.DateTime, Vector{PiecewiseStepData}},
)
    transfd_data = sizehint!(
        SortedDict{Dates.DateTime, Vector{Matrix{Float64}}}(),
        length(data),
    )
    for (k, fd) in data
        transfd_data[k] = _transform_pwl_step_vector_hdf(fd)
    end
    return transform_array_for_hdf(transfd_data)
end

function Base.show(io::IO, ::MIME"text/plain", fd::PiecewiseStepData)
    get(io, :compact, false)::Bool ||
        print(io, "$(typeof(fd)) representing step (piecewise constant) function ")
    print(io, "f(x) =")
    for (y, x1, x2) in zip(fd.y_coords, fd.x_coords[1:(end - 1)], fd.x_coords[2:end])
        print(io, "\n  $y for x in [$x1, $x2)")
    end
end

"""
Calculates the x-length of each segment of a piecewise curve.
"""
function get_x_lengths(pwl::Union{PiecewiseLinearData, PiecewiseStepData})
    return _get_x_lengths(get_x_coords(pwl))
end

Base.length(pwl::Union{PiecewiseLinearData, PiecewiseStepData}) =
    length(get_x_coords(pwl)) - 1

Base.getindex(pwl::PiecewiseLinearData, ix::Int) =
    getindex(get_points(pwl), ix)

Base.:(==)(a::T, b::T) where {T <: FunctionData} = double_equals_from_fields(a, b)

Base.isequal(a::T, b::T) where {T <: FunctionData} = isequal_from_fields(a, b)

Base.hash(a::FunctionData) = hash_from_fields(a)

function _slope_convexity_check(slopes::Vector{Float64})
    for ix in 1:(length(slopes) - 1)
        if slopes[ix] > slopes[ix + 1]
            @debug slopes
            return false
        end
    end
    return true
end

function _slope_concavity_check(slopes::Vector{Float64})
    for ix in 1:(length(slopes) - 1)
        if slopes[ix] < slopes[ix + 1]
            @debug slopes
            return false
        end
    end
    return true
end

"""
Returns True/False depending on the convexity of the underlying data
"""
is_convex(pwl::PiecewiseLinearData) =
    _slope_convexity_check(get_slopes(pwl))

is_convex(pwl::PiecewiseStepData) =
    _slope_convexity_check(get_y_coords(pwl))

"""
Returns True/False depending on the concavity of the underlying data.
For piecewise linear data, it checks if the sequence of slopes is non-increasing.
"""
is_concave(pwl::PiecewiseLinearData) =
    _slope_concavity_check(get_slopes(pwl))

is_concave(pwl::PiecewiseStepData) =
    _slope_concavity_check(get_y_coords(pwl))

# CONVEX APPROXIMATION FUNCTIONS

"""
    isotonic_regression(values::Vector{Float64}, weights::Vector{Float64}) -> Vector{Float64}

Pool Adjacent Violators Algorithm (PAVA) for weighted isotonic regression.
Returns the closest (weighted L2) non-decreasing sequence to `values`.

This is an O(n) algorithm that finds the optimal monotonically non-decreasing
approximation to the input values.
"""
function isotonic_regression(values::Vector{Float64}, weights::Vector{Float64})
    n = length(values)
    n == 0 && return Float64[]
    length(weights) != n &&
        throw(ArgumentError("values and weights must have the same length"))

    # Initialize: each element is its own block
    # Store tuples of (start_index, end_index, weighted_sum, total_weight)
    blocks = Vector{NTuple{4, Float64}}(undef, n)
    for i in 1:n
        blocks[i] = (Float64(i), Float64(i), values[i] * weights[i], weights[i])
    end

    # Merge blocks that violate monotonicity
    num_blocks = n
    i = 1
    while i < num_blocks
        # Get weighted averages
        avg_curr = blocks[i][3] / blocks[i][4]
        avg_next = blocks[i + 1][3] / blocks[i + 1][4]

        if avg_curr > avg_next  # Violation: merge blocks
            # Merge blocks[i] and blocks[i+1]
            merged = (
                blocks[i][1],                          # start
                blocks[i + 1][2],                      # end
                blocks[i][3] + blocks[i + 1][3],       # sum of weighted values
                blocks[i][4] + blocks[i + 1][4],       # sum of weights
            )

            # Shift blocks down
            blocks[i] = merged
            for j in (i + 1):(num_blocks - 1)
                blocks[j] = blocks[j + 1]
            end
            num_blocks -= 1

            # Step back to check if previous block now violates
            i = max(1, i - 1)
        else
            i += 1
        end
    end

    # Expand blocks back to full result
    result = Vector{Float64}(undef, n)
    for block_idx in 1:num_blocks
        start_idx = Int(blocks[block_idx][1])
        end_idx = Int(blocks[block_idx][2])
        avg = blocks[block_idx][3] / blocks[block_idx][4]
        for j in start_idx:end_idx
            result[j] = avg
        end
    end

    return result
end

"""
Compute weights for isotonic regression based on the weighting scheme.

# Arguments
- `x_coords::Vector{Float64}`: x-coordinates of the piecewise data
- `weights`: weighting scheme
  - `:uniform` - all segments weighted equally
  - `:length` - segments weighted by their x-length (default)
  - `Vector{Float64}` - custom weights
"""
function _compute_convex_weights(x_coords::Vector{Float64}, weights)
    n_segments = length(x_coords) - 1
    if weights === :uniform
        return ones(n_segments)
    elseif weights === :length
        return _get_x_lengths(x_coords)
    elseif weights isa Vector{Float64}
        length(weights) == n_segments ||
            throw(ArgumentError("Custom weights must have length $n_segments, got $(length(weights))"))
        return weights
    else
        throw(ArgumentError("weights must be :uniform, :length, or Vector{Float64}"))
    end
end

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

serialize(val::FunctionData) = serialize_struct(val)

deserialize(T::Type{<:FunctionData}, val::Dict) = deserialize_struct(T, val)

deserialize(::Type{FunctionData}, val::Dict) =
    throw(ArgumentError("FunctionData is abstract, must specify a concrete subtype"))

# FunctionData support fetching "raw data" to support cases where we might want to store
# their data in a different container in its most purely numerical form, such as in
# PowerSimulations.

"""
Get from a subtype or instance of FunctionData the type of data its `get_raw_data` method
returns
"""
function get_raw_data_type end
get_raw_data_type(::Union{LinearFunctionData, Type{LinearFunctionData}}) =
    NTuple{2, Float64}
get_raw_data_type(::Union{QuadraticFunctionData, Type{QuadraticFunctionData}}) =
    NTuple{3, Float64}
get_raw_data_type(::Union{PiecewiseLinearData, Type{PiecewiseLinearData}}) =
    Vector{Tuple{Float64, Float64}}
get_raw_data_type(::Union{PiecewiseStepData, Type{PiecewiseStepData}}) =
    Matrix{Float64}

"Losslessly convert `LinearFunctionData` to `QuadraticFunctionData`"
QuadraticFunctionData(data::LinearFunctionData) =
    QuadraticFunctionData(0, get_proportional_term(data), get_constant_term(data))

"Losslessly convert `LinearFunctionData` to `QuadraticFunctionData`"
Base.convert(::Type{QuadraticFunctionData}, data::LinearFunctionData) =
    QuadraticFunctionData(data)

# GET_DOMAIN
"Get the domain of the function represented by the `LinearFunctionData` or `QuadraticFunctionData` (always `(-Inf, Inf)` for these types)."
get_domain(::Union{LinearFunctionData, QuadraticFunctionData}) = (-Inf, Inf)

"Get the domain of the function represented by the `PiecewiseLinearData`."
get_domain(fd::PiecewiseLinearData) =
    (first(get_points(fd)).x, last(get_points(fd)).x)  # avoiding get_x_coords to avoid extra allocation

"Get the domain of the function represented by the `PiecewiseStepData`."
get_domain(fd::PiecewiseStepData) =
    (first(get_x_coords(fd)), last(get_x_coords(fd)))

# ZERO
"Get a `LinearFunctionData` representing the function `f(x) = 0`"
Base.zero(::Union{LinearFunctionData, Type{LinearFunctionData}}) = LinearFunctionData(0, 0)

"Get a `QuadraticFunctionData` representing the function `f(x) = 0`"
Base.zero(::Union{QuadraticFunctionData, Type{QuadraticFunctionData}}) =
    QuadraticFunctionData(0, 0, 0)

"Get a `PiecewiseLinearData` representing the function `f(x) = 0`; optionally specify `domain` tuple to set the x-coordinates of the endpoints"
Base.zero(::Type{PiecewiseLinearData}; domain::Tuple{Real, Real} = (-Inf, Inf)) =
    PiecewiseLinearData([(first(domain), 0), (last(domain), 0)])

"Get a `PiecewiseStepData` representing the function `f(x) = 0`; optionally specify `domain` tuple to set the x-coordinates of the endpoints"
Base.zero(::Type{PiecewiseStepData}; domain::Tuple{Real, Real} = (-Inf, Inf)) =
    PiecewiseStepData([domain...], [0])

"Get a `PiecewiseLinearData` with the same x-coordinates as `fd` but y-coordinates equal to zero"
Base.zero(fd::PiecewiseLinearData) =
    PiecewiseLinearData([(p.x, 0.0) for p in get_points(fd)])

"Get a `PiecewiseStepData` with the same x-coordinates as `fd` and y-coordinates equal to zero"
Base.zero(fd::PiecewiseStepData) =
    PiecewiseStepData(get_x_coords(fd), zeros(length(get_y_coords(fd))))

"Get a `FunctionData` representing the function `f(x) = 0`"
Base.zero(::Union{FunctionData, Type{FunctionData}}) = Base.zero(LinearFunctionData)

# SCALAR MULTIPLICATION
"Multiply the `LinearFunctionData` by a scalar: (c * f)(x) = c * f(x)"
Base.:*(c::Real, fd::LinearFunctionData) =
    LinearFunctionData(
        c * get_proportional_term(fd),
        c * get_constant_term(fd),
    )

"Multiply the `QuadraticFunctionData` by a scalar: (c * f)(x) = c * f(x)"
Base.:*(c::Real, fd::QuadraticFunctionData) =
    QuadraticFunctionData(
        c * get_quadratic_term(fd),
        c * get_proportional_term(fd),
        c * get_constant_term(fd),
    )

"Multiply the `PiecewiseLinearData` by a scalar: (c * f)(x) = c * f(x)"
Base.:*(c::Real, fd::PiecewiseLinearData) =
    PiecewiseLinearData(
        [(p.x, c * p.y) for p in get_points(fd)],
    )

"Multiply the `PiecewiseStepData` by a scalar: (c * f)(x) = c * f(x)"
Base.:*(c::Real, fd::PiecewiseStepData) =
    PiecewiseStepData(
        get_x_coords(fd),
        c * get_y_coords(fd),
    )

# commutativity
"Multiply the `FunctionData` by a scalar: (f * c)(x) = (c * f)(x) = c * f(x)"
Base.:*(fd::FunctionData, c::Real) = c * fd

# SCALAR ADDITION
"Add a scalar to the `LinearFunctionData`: (f + c)(x) = f(x) + c"
Base.:+(fd::LinearFunctionData, c::Real) =
    LinearFunctionData(
        get_proportional_term(fd),
        get_constant_term(fd) + c,
    )

"Add a scalar to the `QuadraticFunctionData`: (f + c)(x) = f(x) + c"
Base.:+(fd::QuadraticFunctionData, c::Real) =
    QuadraticFunctionData(
        get_quadratic_term(fd),
        get_proportional_term(fd),
        get_constant_term(fd) + c,
    )

"Add a scalar to the `PiecewiseLinearData`: (f + c)(x) = f(x) + c"
Base.:+(fd::PiecewiseLinearData, c::Real) =
    PiecewiseLinearData(
        [(p.x, p.y + c) for p in get_points(fd)],
    )

"Add a scalar to the `PiecewiseStepData`: (f + c)(x) = f(x) + c"
Base.:+(fd::PiecewiseStepData, c::Real) =
    PiecewiseStepData(
        get_x_coords(fd),
        get_y_coords(fd) .+ c,
    )

# commutativity
"Add a scalar to the `FunctionData`: (c + f)(x) = (f + c)(x) = f(x) + c"
Base.:+(c::Real, fd::FunctionData) = fd + c

# SHIFT BY A SCALAR
"Right shift the `LinearFunctionData` by a scalar: (f >> c)(x) = f(x - c)"
Base.:>>(fd::LinearFunctionData, c::Real) =
    LinearFunctionData(
        get_proportional_term(fd),
        get_constant_term(fd) - get_proportional_term(fd) * c,
    )

"Right shift the `QuadraticFunctionData` by a scalar: (f >> c)(x) = f(x - c)"
Base.:>>(fd::QuadraticFunctionData, c::Real) =
    QuadraticFunctionData(
        get_quadratic_term(fd),
        get_proportional_term(fd) - 2 * get_quadratic_term(fd) * c,
        get_constant_term(fd) +
        get_quadratic_term(fd) * c^2 - get_proportional_term(fd) * c,
    )

"Right shift the `PiecewiseLinearData` by a scalar: (f >> c)(x) = f(x - c)"
Base.:>>(fd::PiecewiseLinearData, c::Real) =
    PiecewiseLinearData(
        [(p.x + c, p.y) for p in get_points(fd)],
    )

"Right shift the `PiecewiseStepData` by a scalar: (f >> c)(x) = f(x - c)"
Base.:>>(fd::PiecewiseStepData, c::Real) =
    PiecewiseStepData(
        get_x_coords(fd) .+ c,
        get_y_coords(fd),
    )

"Left shift the `FunctionData` by a scalar: (f << c)(x) = (f >> -c)(x) = f(x + c)"
Base.:<<(fd::FunctionData, c::Real) = fd >> -c

# NEGATION
"Negate the `FunctionData`: (-f)(x) = -f(x)"
Base.:-(fd::FunctionData) = -1.0 * fd

# FLIP ABOUT Y-AXIS
"Flip the `LinearFunctionData` about the y-axis: (~f)(x) = f(-x)"
Base.:~(fd::LinearFunctionData) =
    LinearFunctionData(
        -get_proportional_term(fd),
        get_constant_term(fd),
    )

"Flip the `QuadraticFunctionData` about the y-axis: (~f)(x) = f(-x)"
Base.:~(fd::QuadraticFunctionData) =
    QuadraticFunctionData(
        get_quadratic_term(fd),
        -get_proportional_term(fd),
        get_constant_term(fd),
    )

"Flip the `PiecewiseLinearData` about the y-axis: (~f)(x) = f(-x)"
Base.:~(fd::PiecewiseLinearData) =
    PiecewiseLinearData(
        [(-p.x, p.y) for p in reverse(get_points(fd))],
    )

"Flip the `PiecewiseStepData` about the y-axis: (~f)(x) = f(-x)"
Base.:~(fd::PiecewiseStepData) =
    PiecewiseStepData(
        reverse(-get_x_coords(fd)),
        reverse(get_y_coords(fd)),
    )

# ADDITION OF TWO FUNCTIONDATAS
"Add two `LinearFunctionData`s: (f + g)(x) = f(x) + g(x)"
Base.:+(f::LinearFunctionData, g::LinearFunctionData) =
    LinearFunctionData(
        get_proportional_term(f) + get_proportional_term(g),
        get_constant_term(f) + get_constant_term(g),
    )

"Add two `QuadraticFunctionData`s: (f + g)(x) = f(x) + g(x)"
Base.:+(f::QuadraticFunctionData, g::QuadraticFunctionData) =
    QuadraticFunctionData(
        get_quadratic_term(f) + get_quadratic_term(g),
        get_proportional_term(f) + get_proportional_term(g),
        get_constant_term(f) + get_constant_term(g),
    )

"Add two `PiecewiseLinearData`s: (f + g)(x) = f(x) + g(x). Errors if the x-coordinates are not the same."
function Base.:+(f::PiecewiseLinearData, g::PiecewiseLinearData)
    f_x_coords = get_x_coords(f)
    g_x_coords = get_x_coords(g)
    all(isapprox.(f_x_coords, g_x_coords)) ||
        throw(
            ArgumentError(
                "Cannot add PiecewiseLinearData with different x-coordinates: " *
                "f x-coords = $f_x_coords, g x-coords = $g_x_coords",
            ),
        )
    new_points = XY_COORDS[
        (x = f_x, y = f_y + g_y) for
        (f_x, f_y, g_y) in zip(f_x_coords, get_y_coords(f), get_y_coords(g))
    ]
    return PiecewiseLinearData(new_points)
end

"Add two `PiecewiseStepData`s: (f + g)(x) = f(x) + g(x). Errors if the x-coordinates are not the same."
function Base.:+(f::PiecewiseStepData, g::PiecewiseStepData)
    f_x_coords = get_x_coords(f)
    g_x_coords = get_x_coords(g)
    all(isapprox.(f_x_coords, g_x_coords)) ||
        throw(
            ArgumentError(
                "Cannot add PiecewiseStepData with different x-coordinates: " *
                "f x-coords = $f_x_coords, g x-coords = $g_x_coords",
            ),
        )
    new_y_coords = get_y_coords(f) .+ get_y_coords(g)
    return PiecewiseStepData(f_x_coords, new_y_coords)
end

# FUNCTION EVALUATION
"Evaluate the `LinearFunctionData` at a given x-coordinate"
(fd::LinearFunctionData)(x::Number) =
    get_proportional_term(fd) * x + get_constant_term(fd)

"Evaluate the `QuadraticFunctionData` at a given x-coordinate"
(fd::QuadraticFunctionData)(x::Number) =
    get_quadratic_term(fd) * x^2 + get_proportional_term(fd) * x + get_constant_term(fd)

_eval_fd_impl(
    i::Int64,
    x::Real,
    x_coords::Vector{Float64},
    y_coords::Vector{Float64},
    ::PiecewiseLinearData,
) =
    y_coords[i] +
    (y_coords[i + 1] - y_coords[i]) *
    (x - x_coords[i]) /
    (x_coords[i + 1] - x_coords[i])

_eval_fd_impl(
    i::Int64,
    ::Real,
    ::Vector{Float64},
    y_coords::Vector{Float64},
    ::PiecewiseStepData,
) =
    y_coords[i]

"Evaluate the `PiecewiseLinearData` or `PiecewiseStepData` at a given x-coordinate"
function (fd::Union{PiecewiseLinearData, PiecewiseStepData})(x::Real)
    lb, ub = get_domain(fd)
    (x < lb || x > ub) &&
        throw(ArgumentError("x=$x is outside the domain [$lb, $ub]"))
    x_coords = get_x_coords(fd)
    y_coords = get_y_coords(fd)
    i_leq = searchsortedlast(x_coords, x)  # uses binary search!
    (i_leq == length(x_coords)) && return last(y_coords)
    return _eval_fd_impl(i_leq, x, x_coords, y_coords, fd)
end
