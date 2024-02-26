abstract type FunctionData end

"""
Structure to represent the underlying data of linear functions. Principally used for
the representation of cost functions `f(x) = proportional_term*x`.

# Arguments
 - `proportional_term::Float64`: the proportional term in the function
   `f(x) = proportional_term*x`
"""
struct LinearFunctionData <: FunctionData
    proportional_term::Float64
end

get_proportional_term(fd::LinearFunctionData) = fd.proportional_term

"""
Structure to represent the underlying data of quadratic polynomial functions. Principally
used for the representation of cost functions
`f(x) = quadratic_term*x^2 + proportional_term*x + constant_term`.

# Arguments
 - `quadratic_term::Float64`: the quadratic term in the represented function
 - `proportional_term::Float64`: the proportional term in the represented function
 - `constant_term::Float64`: the constant term in the represented function
"""
struct QuadraticFunctionData <: FunctionData
    quadratic_term::Float64
    proportional_term::Float64
    constant_term::Float64
end

get_quadratic_term(fd::QuadraticFunctionData) = fd.quadratic_term
get_proportional_term(fd::QuadraticFunctionData) = fd.proportional_term
get_constant_term(fd::QuadraticFunctionData) = fd.constant_term

"""
Structure to represent the underlying data of higher order polynomials. Principally used for
the representation of cost functions where
`f(x) = sum_{i in keys(coefficients)} coefficients[i]*x^i`.

# Arguments
 - `coefficients::Dict{Int, Float64}`: values are coefficients, keys are degrees to which
   the coefficients apply (0 for the constant term, 2 for the squared term, etc.)
"""
struct PolynomialFunctionData <: FunctionData
    coefficients::Dict{Int, Float64}
end

get_coefficients(fd::PolynomialFunctionData) = fd.coefficients

function _validate_piecewise_x(x_coords)
    # TODO currently there exist cases where we are constructing a PiecewiseLinearPointData
    # with only one point (e.g., `calculate_variable_cost` within
    # `power_system_table_data.jl`) -- what does this represent?
    # (length(x_coords) >= 2) ||
    #     throw(ArgumentError("Must specify at least two x-coordinates"))
    issorted(x_coords) || throw(ArgumentError("Piecewise x-coordinates must be ascending"))
end

"""
Structure to represent  pointwise piecewise linear data. Principally used for the
representation of cost functions where the points store quantities (x, y), such as (MW, \$).
The curve starts at the first point given, not the origin.

# Arguments
 - `points::Vector{@NamedTuple{x::Float64, y::Float64}}`: the points that define the function
"""
struct PiecewiseLinearPointData <: FunctionData
    points::Vector{@NamedTuple{x::Float64, y::Float64}}

    function PiecewiseLinearPointData(points::Vector{<:NamedTuple{(:x, :y)}})
        _validate_piecewise_x(first.(points))
        return new(points)
    end
end

function PiecewiseLinearPointData(points::Vector{<:NamedTuple})
    throw(
        ArgumentError(
            "If constructing PiecewiseLinearPointData with NamedTuples, points must have type Vector{<:NamedTuple{(:x, :y)}}; got $(typeof(points))",
        ),
    )
end

function _convert_to_xy(point)
    # Need to be able to handle dicts for deserialization
    if point isa AbstractDict
        (keys(point) == Set(["x", "y"])) && return (x = point["x"], y = point["y"])
        throw(
            ArgumentError(
                "If constructing PiecewiseLinearPointData with dictionaries, keys must be [\"x\", \"y\"]; got $(collect(keys(point)))",
            ),
        )
    end
    return NamedTuple{(:x, :y)}(point)
end

function PiecewiseLinearPointData(points::Vector)
    PiecewiseLinearPointData(_convert_to_xy.(points))
end

"Get the points that define the piecewise data"
get_points(data::PiecewiseLinearPointData) = data.points

"Get the x-coordinates of the points that define the piecewise data"
get_x_coords(data::PiecewiseLinearPointData) = first.(get_points(data))

function _get_slopes(vc::Vector{@NamedTuple{x::Float64, y::Float64}})
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
Calculates the slopes of the line segments defined by the PiecewiseLinearPointData,
returning one fewer slope than the number of underlying points.
"""
function get_slopes(pwl::PiecewiseLinearPointData)
    return _get_slopes(get_points(pwl))
end

"""
Structure to represent the underlying data of slope piecewise linear data. Principally used
for the representation of cost functions where the points store quantities (x, dy/dx), such
as (MW, \$/MW).

# Arguments
 - `x_coords::Vector{Float64}`: the x-coordinates of the endpoints of the segments
 - `y0::Float64`: the y-coordinate of the data at the first x-coordinate
 - `slopes::Vector{Float64}`: the slopes of the segments: `slopes[1]` is the slope between
   `x_coords[1]` and `x_coords[2]`, etc.
"""
struct PiecewiseLinearSlopeData <: FunctionData
    x_coords::Vector{Float64}
    y0::Float64
    slopes::Vector{Float64}

    function PiecewiseLinearSlopeData(x_coords, y0, slopes)
        _validate_piecewise_x(x_coords)
        (length(slopes) == length(x_coords) - 1) ||
            throw(ArgumentError("Must specify one fewer slope than x-coordinates"))
        return new(x_coords, y0, slopes)
    end
end

"Get the slopes that define the PiecewiseLinearSlopeData"
get_slopes(data::PiecewiseLinearSlopeData) = data.slopes

"Get the x-coordinates of the points that define the piecewise data"
get_x_coords(data::PiecewiseLinearSlopeData) = data.x_coords

"Get the y-coordinate of the data at the first x-coordinate"
get_y0(data::PiecewiseLinearSlopeData) = data.y0

"Calculate the endpoints of the segments in the PiecewiseLinearSlopeData"
function get_points(data::PiecewiseLinearSlopeData)
    slopes = get_slopes(data)
    x_coords = get_x_coords(data)
    points = Vector{@NamedTuple{x::Float64, y::Float64}}(undef, length(x_coords))
    running_y = get_y0(data)
    points[1] = (x = x_coords[1], y = running_y)
    for (i, (prev_slope, this_x, dx)) in
        enumerate(zip(slopes, x_coords[2:end], get_x_lengths(data)))
        running_y += prev_slope * dx
        points[i + 1] = (x = this_x, y = running_y)
    end
    return points
end

"""
Calculates the x-length of each segment of a piecewise curve.
"""
function get_x_lengths(
    pwl::Union{PiecewiseLinearPointData, PiecewiseLinearSlopeData},
)
    return _get_x_lengths(get_x_coords(pwl))
end

Base.length(pwl::Union{PiecewiseLinearPointData, PiecewiseLinearSlopeData}) =
    length(get_x_coords(pwl)) - 1

Base.getindex(pwl::PiecewiseLinearPointData, ix::Int) =
    getindex(get_points(pwl), ix)

Base.:(==)(a::PiecewiseLinearPointData, b::PiecewiseLinearPointData) =
    get_points(a) == get_points(b)

Base.:(==)(a::PiecewiseLinearSlopeData, b::PiecewiseLinearSlopeData) =
    (get_x_coords(a) == get_x_coords(b)) &&
    (get_y0(a) == get_y0(b)) &&
    (get_slopes(a) == get_slopes(b))

Base.:(==)(a::PolynomialFunctionData, b::PolynomialFunctionData) =
    get_coefficients(a) == get_coefficients(b)

function _slope_convexity_check(slopes::Vector{Float64})
    for ix in 1:(length(slopes) - 1)
        if slopes[ix] > slopes[ix + 1]
            @debug slopes
            return false
        end
    end
    return true
end

"""
Returns True/False depending on the convexity of the underlying data
"""
is_convex(pwl::Union{PiecewiseLinearPointData, PiecewiseLinearSlopeData}) =
    _slope_convexity_check(get_slopes(pwl))

# kwargs-only constructors for deserialization
LinearFunctionData(; proportional_term) = LinearFunctionData(proportional_term)

QuadraticFunctionData(; quadratic_term, proportional_term, constant_term) =
    QuadraticFunctionData(quadratic_term, proportional_term, constant_term)

PolynomialFunctionData(; coefficients) = PolynomialFunctionData(coefficients)

PiecewiseLinearPointData(; points) = PiecewiseLinearPointData(points)

PiecewiseLinearSlopeData(; x_coords, y0, slopes) =
    PiecewiseLinearSlopeData(x_coords, y0, slopes)

serialize(val::FunctionData) = serialize_struct(val)

function deserialize_struct(T::Type{PolynomialFunctionData}, val::Dict)
    data = deserialize_to_dict(T, val)
    data[Symbol("coefficients")] =
        Dict(
            (k isa String ? parse(Int, k) : k, v)
            for (k, v) in data[Symbol("coefficients")]
        )
    return T(; data...)
end

deserialize(T::Type{<:FunctionData}, val::Dict) = deserialize_struct(T, val)

deserialize(::Type{FunctionData}, val::Dict) =
    throw(ArgumentError("FunctionData is abstract, must specify a concrete subtype"))

# FunctionData support fetching "raw data" to support cases where we might want to store
# their data in a different container in its most purely numerical form, such as in
# PowerSimulations.

"""
Get a bare numerical representation of the data represented by the FunctionData
"""
function get_raw_data end
get_raw_data(fd::LinearFunctionData) = get_proportional_term(fd)
get_raw_data(fd::QuadraticFunctionData) =
    (get_quadratic_term(fd), get_proportional_term(fd), get_constant_term(fd))
get_raw_data(fd::PolynomialFunctionData) =
    sort([(degree, coeff) for (degree, coeff) in get_coefficients(fd)]; by = first)
get_raw_data(fd::PiecewiseLinearPointData) = Tuple.(get_points(fd))
function get_raw_data(fd::PiecewiseLinearSlopeData)
    x_coords = get_x_coords(fd)
    return vcat((x_coords[1], get_y0(fd)), collect(zip(x_coords[2:end], get_slopes(fd))))
end

"""
Get from a subtype of FunctionData the type of data its get_raw_data method returns
"""
function get_raw_data_type end
get_raw_data_type(::Union{LinearFunctionData, Type{LinearFunctionData}}) = Float64
get_raw_data_type(::Union{QuadraticFunctionData, Type{QuadraticFunctionData}}) =
    NTuple{3, Float64}
get_raw_data_type(::Union{PolynomialFunctionData, Type{PolynomialFunctionData}}) =
    Vector{Tuple{Int, Float64}}
get_raw_data_type(::Union{PiecewiseLinearPointData, Type{PiecewiseLinearPointData}}) =
    Vector{Tuple{Float64, Float64}}
get_raw_data_type(::Union{PiecewiseLinearSlopeData, Type{PiecewiseLinearSlopeData}}) =
    Vector{Tuple{Float64, Float64}}
