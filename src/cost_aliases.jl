# Cost aliases: a simplified interface to the portion of the parametric
# `ValueCurve{FunctionData}` design that the user is likely to interact with. Each alias
# consists of a simple name for a particular `ValueCurve{FunctionData}` type, a constructor
# and methods to interact with it without having to think about `FunctionData`, and
# overridden printing behavior to complete the illusion. Everything here (aside from the
# overridden printing) is properly speaking mere syntactic sugar for the underlying
# `ValueCurve{FunctionData}` design. One could imagine similar convenience constructors and
# methods being defined for all the `ValueCurve{FunctionData}` types, not just the ones we
# have here nicely packaged and presented to the user.

# Default `is_cost_alias` is defined in value_curve.jl so it's available to
# time_series_value_curve.jl show methods (included before this file).

"""
    LinearCurve(proportional_term::Float64)
    LinearCurve(proportional_term::Float64, constant_term::Float64)

A linear input-output curve, representing a constant marginal rate. May have zero no-load
cost (i.e., constant average rate) or not.

# Arguments
- `proportional_term::Float64`: marginal rate
- `constant_term::Float64`: optional, cost at zero production, defaults to `0.0`
"""
const LinearCurve = InputOutputCurve{LinearFunctionData}

is_cost_alias(::Union{LinearCurve, Type{LinearCurve}}) = true

InputOutputCurve{LinearFunctionData}(proportional_term::Real) =
    InputOutputCurve(LinearFunctionData(proportional_term))

InputOutputCurve{LinearFunctionData}(proportional_term::Real, constant_term::Real) =
    InputOutputCurve(LinearFunctionData(proportional_term, constant_term))

"Get the proportional term (i.e., slope) of the `LinearCurve`"
get_proportional_term(vc::LinearCurve) = get_proportional_term(get_function_data(vc))

"Get the constant term (i.e., intercept) of the `LinearCurve`"
get_constant_term(vc::LinearCurve) = get_constant_term(get_function_data(vc))

Base.show(io::IO, vc::LinearCurve) =
    if isnothing(get_input_at_zero(vc))
        print(io, "$(typeof(vc))($(get_proportional_term(vc)), $(get_constant_term(vc)))")
    else
        Base.show_default(io, vc)
    end

"""
    QuadraticCurve(quadratic_term::Float64, proportional_term::Float64, constant_term::Float64)

A quadratic input-output curve, may have nonzero no-load cost.

# Arguments
- `quadratic_term::Float64`: quadratic term of the curve
- `proportional_term::Float64`: proportional term of the curve
- `constant_term::Float64`: constant term of the curve
"""
const QuadraticCurve = InputOutputCurve{QuadraticFunctionData}

is_cost_alias(::Union{QuadraticCurve, Type{QuadraticCurve}}) = true

InputOutputCurve{QuadraticFunctionData}(quadratic_term, proportional_term, constant_term) =
    InputOutputCurve(
        QuadraticFunctionData(quadratic_term, proportional_term, constant_term),
    )

"Get the quadratic term of the `QuadraticCurve`"
get_quadratic_term(vc::QuadraticCurve) = get_quadratic_term(get_function_data(vc))

"Get the proportional (i.e., linear) term of the `QuadraticCurve`"
get_proportional_term(vc::QuadraticCurve) = get_proportional_term(get_function_data(vc))

"Get the constant term of the `QuadraticCurve`"
get_constant_term(vc::QuadraticCurve) = get_constant_term(get_function_data(vc))

Base.show(io::IO, vc::QuadraticCurve) =
    if isnothing(get_input_at_zero(vc))
        print(
            io,
            "$(typeof(vc))($(get_quadratic_term(vc)), $(get_proportional_term(vc)), $(get_constant_term(vc)))",
        )
    else
        Base.show_default(io, vc)
    end

"""
    PiecewisePointCurve(points::Vector{Tuple{Float64, Float64}})

A piecewise linear curve specified by cost values at production points.

# Arguments
- `points::Vector{Tuple{Float64, Float64}}` or similar: vector of `(production, cost)` pairs
"""
const PiecewisePointCurve = InputOutputCurve{PiecewiseLinearData}

is_cost_alias(::Union{PiecewisePointCurve, Type{PiecewisePointCurve}}) = true

InputOutputCurve{PiecewiseLinearData}(points::Vector) =
    InputOutputCurve(PiecewiseLinearData(points))

"Get the points that define the `PiecewisePointCurve`"
get_points(vc::PiecewisePointCurve) = get_points(get_function_data(vc))

"Get the x-coordinates of the points that define the `PiecewisePointCurve`"
get_x_coords(vc::PiecewisePointCurve) = get_x_coords(get_function_data(vc))

"Get the y-coordinates of the points that define the `PiecewisePointCurve`"
get_y_coords(vc::PiecewisePointCurve) = get_y_coords(get_function_data(vc))

"Calculate the slopes of the line segments defined by the `PiecewisePointCurve`"
get_slopes(vc::PiecewisePointCurve) = get_slopes(get_function_data(vc))

# Here we manually circumvent the @NamedTuple{x::Float64, y::Float64} type annotation, but we keep things looking like named tuples
Base.show(io::IO, vc::PiecewisePointCurve) =
    if isnothing(get_input_at_zero(vc))
        print(io, "$(typeof(vc))([$(join(get_points(vc), ", "))])")
    else
        Base.show_default(io, vc)
    end

"""
    PiecewiseIncrementalCurve(initial_input::Union{Float64, Nothing}, x_coords::Vector{Float64}, slopes::Vector{Float64})
    PiecewiseIncrementalCurve(input_at_zero::Union{Nothing, Float64}, initial_input::Union{Float64, Nothing}, x_coords::Vector{Float64}, slopes::Vector{Float64})

A piecewise linear curve specified by marginal rates (slopes) between production points. May
have nonzero initial value.

# Arguments
- `input_at_zero::Union{Nothing, Float64}`: (optional, defaults to `nothing`) cost at zero production, does NOT represent a part of the curve
- `initial_input::Union{Float64, Nothing}`: cost at minimum production point `first(x_coords)` (NOT at zero production), defines the start of the curve
- `x_coords::Vector{Float64}`: vector of `n` production points
- `slopes::Vector{Float64}`: vector of `n-1` marginal rates/slopes of the curve segments between
  the points
"""
const PiecewiseIncrementalCurve = IncrementalCurve{PiecewiseStepData}

is_cost_alias(::Union{PiecewiseIncrementalCurve, Type{PiecewiseIncrementalCurve}}) = true

IncrementalCurve{PiecewiseStepData}(initial_input, x_coords::Vector, slopes::Vector) =
    IncrementalCurve(PiecewiseStepData(x_coords, slopes), initial_input)

IncrementalCurve{PiecewiseStepData}(
    input_at_zero,
    initial_input,
    x_coords::Vector,
    slopes::Vector,
) =
    IncrementalCurve(PiecewiseStepData(x_coords, slopes), initial_input, input_at_zero)

"Get the x-coordinates that define the `PiecewiseIncrementalCurve`"
get_x_coords(vc::PiecewiseIncrementalCurve) = get_x_coords(get_function_data(vc))

"Fetch the slopes that define the `PiecewiseIncrementalCurve`"
get_slopes(vc::PiecewiseIncrementalCurve) = get_y_coords(get_function_data(vc))

Base.show(io::IO, vc::PiecewiseIncrementalCurve) =
    print(
        io,
        if isnothing(get_input_at_zero(vc))
            "$(typeof(vc))($(get_initial_input(vc)), $(get_x_coords(vc)), $(get_slopes(vc)))"
        else
            "$(typeof(vc))($(get_input_at_zero(vc)), $(get_initial_input(vc)), $(get_x_coords(vc)), $(get_slopes(vc)))"
        end,
    )

"""
    PiecewiseAverageCurve(initial_input::Union{Float64, Nothing}, x_coords::Vector{Float64}, slopes::Vector{Float64})

A piecewise linear curve specified by average rates between production points. May have
nonzero initial value.

# Arguments
- `initial_input::Union{Float64, Nothing}`: cost at minimum production point `first(x_coords)` (NOT at zero production), defines the start of the curve
- `x_coords::Vector{Float64}`: vector of `n` production points
- `slopes::Vector{Float64}`: vector of `n-1` average rates/slopes of the curve segments between
  the points
"""
const PiecewiseAverageCurve = AverageRateCurve{PiecewiseStepData}

is_cost_alias(::Union{PiecewiseAverageCurve, Type{PiecewiseAverageCurve}}) = true

AverageRateCurve{PiecewiseStepData}(initial_input, x_coords::Vector, y_coords::Vector) =
    AverageRateCurve(PiecewiseStepData(x_coords, y_coords), initial_input)

"Get the x-coordinates that define the `PiecewiseAverageCurve`"
get_x_coords(vc::PiecewiseAverageCurve) = get_x_coords(get_function_data(vc))

"Get the average rates that define the `PiecewiseAverageCurve`"
get_average_rates(vc::PiecewiseAverageCurve) = get_y_coords(get_function_data(vc))

Base.show(io::IO, vc::PiecewiseAverageCurve) =
    if isnothing(get_input_at_zero(vc))
        print(
            io,
            "$(typeof(vc))($(get_initial_input(vc)), $(get_x_coords(vc)), $(get_average_rates(vc)))",
        )
    else
        Base.show_default(io, vc)
    end

# ── Time-series cost aliases ──────────────────────────────────────────────────

"""
    TimeSeriesLinearCurve

A time-series-backed linear input-output curve. Alias for
`TimeSeriesInputOutputCurve{TimeSeriesLinearFunctionData}`.
"""
const TimeSeriesLinearCurve =
    TimeSeriesInputOutputCurve{TimeSeriesLinearFunctionData}

is_cost_alias(::Union{TimeSeriesLinearCurve, Type{TimeSeriesLinearCurve}}) = true

TimeSeriesInputOutputCurve{TimeSeriesLinearFunctionData}(key::TimeSeriesKey) =
    TimeSeriesInputOutputCurve(TimeSeriesLinearFunctionData(key))

"""
    TimeSeriesQuadraticCurve

A time-series-backed quadratic input-output curve. Alias for
`TimeSeriesInputOutputCurve{TimeSeriesQuadraticFunctionData}`.
"""
const TimeSeriesQuadraticCurve =
    TimeSeriesInputOutputCurve{TimeSeriesQuadraticFunctionData}

is_cost_alias(::Union{TimeSeriesQuadraticCurve, Type{TimeSeriesQuadraticCurve}}) = true

TimeSeriesInputOutputCurve{TimeSeriesQuadraticFunctionData}(key::TimeSeriesKey) =
    TimeSeriesInputOutputCurve(TimeSeriesQuadraticFunctionData(key))

"""
    TimeSeriesPiecewisePointCurve

A time-series-backed piecewise linear input-output curve. Alias for
`TimeSeriesInputOutputCurve{TimeSeriesPiecewiseLinearData}`.
"""
const TimeSeriesPiecewisePointCurve =
    TimeSeriesInputOutputCurve{TimeSeriesPiecewiseLinearData}

is_cost_alias(
    ::Union{TimeSeriesPiecewisePointCurve, Type{TimeSeriesPiecewisePointCurve}},
) = true

TimeSeriesInputOutputCurve{TimeSeriesPiecewiseLinearData}(key::TimeSeriesKey) =
    TimeSeriesInputOutputCurve(TimeSeriesPiecewiseLinearData(key))

"""
    TimeSeriesPiecewiseIncrementalCurve

A time-series-backed piecewise incremental curve. Alias for
`TimeSeriesIncrementalCurve{TimeSeriesPiecewiseStepData}`.
"""
const TimeSeriesPiecewiseIncrementalCurve =
    TimeSeriesIncrementalCurve{TimeSeriesPiecewiseStepData}

is_cost_alias(
    ::Union{
        TimeSeriesPiecewiseIncrementalCurve,
        Type{TimeSeriesPiecewiseIncrementalCurve},
    },
) = true

TimeSeriesIncrementalCurve{TimeSeriesPiecewiseStepData}(
    key::TimeSeriesKey,
    initial_input::Union{Nothing, TimeSeriesKey},
) = TimeSeriesIncrementalCurve(TimeSeriesPiecewiseStepData(key), initial_input)

TimeSeriesIncrementalCurve{TimeSeriesPiecewiseStepData}(
    key::TimeSeriesKey,
    initial_input::Union{Nothing, TimeSeriesKey},
    input_at_zero::Union{Nothing, TimeSeriesKey},
) = TimeSeriesIncrementalCurve(
    TimeSeriesPiecewiseStepData(key), initial_input, input_at_zero,
)

"""
    TimeSeriesPiecewiseAverageCurve

A time-series-backed piecewise average rate curve. Alias for
`TimeSeriesAverageRateCurve{TimeSeriesPiecewiseStepData}`.
"""
const TimeSeriesPiecewiseAverageCurve =
    TimeSeriesAverageRateCurve{TimeSeriesPiecewiseStepData}

is_cost_alias(
    ::Union{
        TimeSeriesPiecewiseAverageCurve,
        Type{TimeSeriesPiecewiseAverageCurve},
    },
) = true

TimeSeriesAverageRateCurve{TimeSeriesPiecewiseStepData}(
    key::TimeSeriesKey,
    initial_input::Union{Nothing, TimeSeriesKey},
) = TimeSeriesAverageRateCurve(TimeSeriesPiecewiseStepData(key), initial_input)

TimeSeriesAverageRateCurve{TimeSeriesPiecewiseStepData}(
    key::TimeSeriesKey,
    initial_input::Union{Nothing, TimeSeriesKey},
    input_at_zero::Union{Nothing, TimeSeriesKey},
) = TimeSeriesAverageRateCurve(
    TimeSeriesPiecewiseStepData(key), initial_input, input_at_zero,
)
