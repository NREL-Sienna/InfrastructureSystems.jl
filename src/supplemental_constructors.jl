
function make_public_forecast(forecast::ForecastInternal, d::TimeSeriesData)
    error("$(typeof(forecast)) must implement make_public_forecast")
end

function make_internal_forecast(forecast::Forecast)
    error("$(typeof(forecast)) must implement make_internal_forecast")
end

"""
    Deterministic(label::String,
                  resolution::Dates.Period,
                  initial_time::Dates.DateTime,
                  time_steps::Int)

Constructs Deterministic after constructing a TimeArray from initial_time and time_steps.
"""
function Deterministic(
    label::String,
    resolution::Dates.Period,
    initial_time::Dates.DateTime,
    time_steps::Int,
)
    data = TimeSeries.TimeArray(
        initial_time:resolution:(initial_time + resolution * (time_steps - 1)),
        ones(time_steps),
    )
    return Deterministic(label, data)
end

function Deterministic(forecasts::Vector{Deterministic})
    @assert !isempty(forecasts)
    timestamps =
        collect(Iterators.flatten((TimeSeries.timestamp(get_data(x)) for x in forecasts)))
    data = collect(Iterators.flatten((TimeSeries.values(get_data(x)) for x in forecasts)))
    ta = TimeSeries.TimeArray(timestamps, data)

    forecast = Deterministic(get_label(forecasts[1]), ta)
    @debug "concatenated forecasts" forecast
    return forecast
end

# TODO: need to make concatenation constructors for Probabilistic and ScenarioBased.

function make_public_forecast(forecast::DeterministicInternal, data::TimeSeries.TimeArray)
    return Deterministic(get_label(forecast), data)
end

function make_internal_forecast(forecast::Deterministic, ts_data::TimeSeriesData)
    return DeterministicInternal(get_label(forecast), ts_data)
end

function DeterministicInternal(label::AbstractString, data::TimeSeriesData)
    return DeterministicInternal(
        label,
        get_resolution(data),
        get_initial_time(data),
        get_uuid(data),
        get_horizon(data),
    )
end

"""
    Probabilistic(
                  label::String,
                  resolution::Dates.Period,
                  initial_time::Dates.DateTime,
                  percentiles::Vector{Float64},
                  time_steps::Int,
                 )
Constructs Probabilistic after constructing a TimeArray from initial_time and time_steps.
"""
function Probabilistic(
    label::String,
    resolution::Dates.Period,
    initial_time::Dates.DateTime,
    percentiles::Vector{Float64},
    time_steps::Int,
)
    data = TimeSeries.TimeArray(
        initial_time:resolution:(initial_time + resolution * (time_steps - 1)),
        ones(time_steps, length(percentiles)),
    )

    return Probabilistic(label, percentiles, data)
end

"""
    Probabilistic(
                  label::String,
                  percentiles::Vector{Float64},  # percentiles for the probabilistic forecast
                  data::TimeSeries.TimeArray,
                 )
Constructs Probabilistic Forecast after constructing a TimeArray from initial_time and time_steps.
"""
# TODO: do we need this check still?
#function Probabilistic(
#                       label::String,
#                       percentiles::Vector{Float64},  # percentiles for the probabilistic forecast
#                       data::TimeSeries.TimeArray,
#                      )
#    if !(length(TimeSeries.colnames(data)) == length(percentiles))
#        throw(DataFormatError(
#            "The size of the provided percentiles and data columns is inconsistent"))
#    end
#    initial_time = TimeSeries.timestamp(data)[1]
#    resolution = get_resolution(data)
#
#    return Probabilistic(label, percentiles, data)
#end

function Probabilistic(
    label::String,
    resolution::Dates.Period,
    initial_time::Dates.DateTime,
    percentiles::Vector{Float64},  # percentiles for the probabilistic forecast
    data::TimeSeries.TimeArray,
)
    return Probabilistic(label, percentiles, data)
end

function make_public_forecast(forecast::ProbabilisticInternal, data::TimeSeries.TimeArray)
    return Probabilistic(get_label(forecast), get_percentiles(forecast), data)
end

function make_internal_forecast(forecast::Probabilistic, ts_data::TimeSeriesData)
    return ProbabilisticInternal(
        get_label(forecast),
        get_resolution(forecast),
        get_initial_time(forecast),
        get_percentiles(forecast),
        get_uuid(ts_data),
        get_horizon(forecast),
    )
end

function ScenarioBased(label::String, data::TimeSeries.TimeArray)
    initial_time = TimeSeries.timestamp(data)[1]
    resolution = get_resolution(data)
    scenario_count = length(TimeSeries.colnames(data))
    return ScenarioBased(label, scenario_count, data)
end

"""
Constructs ScenarioBased Forecast after constructing a TimeArray from initial_time and
time_steps.
"""
function ScenarioBased(
    label::String,
    resolution::Dates.Period,
    initial_time::Dates.DateTime,
    scenario_count::Int,
    time_steps::Int,
)
    data = TimeSeries.TimeArray(
        initial_time:resolution:(initial_time + resolution * (time_steps - 1)),
        ones(time_steps, scenario_count),
    )

    return ScenarioBased(label, data)
end

function ScenarioBased(forecasts::Vector{ScenarioBased})
    @assert !isempty(forecasts)
    scenario_count = get_scenario_count(forecasts[1])
    colnames = TimeSeries.colnames(get_data(forecasts[1]))
    data = Array{Any}(undef, 0, scenario_count)
    timestamps =
        collect(Iterators.flatten((TimeSeries.timestamp(get_data(x)) for x in forecasts)))
    for x in forecasts
        data = vcat(data, TimeSeries.values(get_data(x)))
    end
    ta = TimeSeries.TimeArray(timestamps, data, colnames)

    forecast = ScenarioBased(get_label(forecasts[1]), ta)
    @debug "concatenated forecasts" forecast
    return forecast
end

function make_public_forecast(forecast::ScenarioBasedInternal, data::TimeSeries.TimeArray)
    return ScenarioBased(get_label(forecast), data)
end

function make_internal_forecast(forecast::ScenarioBased, ts_data::TimeSeriesData)
    return ScenarioBasedInternal(
        get_label(forecast),
        get_resolution(forecast),
        get_initial_time(forecast),
        get_scenario_count(forecast),
        get_uuid(ts_data),
        get_horizon(forecast),
    )
end

function CostCoefficient(label::String, data::TimeSeries.TimeArray)
    initial_time = TimeSeries.timestamp(data)[1]
    resolution = get_resolution(data)
    breakpoints = length(TimeSeries.colnames(data)) / 2
    return CostCoefficient(label, breakpoints, data)
end

"""
Constructs CostCoefficient Forecast after constructing a TimeArray from initial_time and
time_steps.
"""
function CostCoefficient(
    label::String,
    resolution::Dates.Period,
    initial_time::Dates.DateTime,
    break_points::Int,
    time_steps::Int,
)
    name = collect(Iterators.flatten([
        (Symbol("cost_bp$(ix)"), Symbol("load_bp$ix")) for ix in 1:break_points
    ]))
    data = TimeSeries.TimeArray(
        initial_time:resolution:(initial_time + resolution * (time_steps - 1)),
        ones(time_steps, break_points),
        name,
    )

    return CostCoefficient(label, break_points, data)
end

function CostCoefficient(forecasts::Vector{CostCoefficient})
    @assert !isempty(forecasts)
    break_points = get_break_points(forecasts[1])
    colnames = TimeSeries.colnames(get_data(forecasts[1]))
    data = Array{Any}(undef, 0, break_points)
    timestamps =
        collect(Iterators.flatten((TimeSeries.timestamp(get_data(x)) for x in forecasts)))
    for x in forecasts
        data = vcat(data, TimeSeries.values(get_data(x)))
    end
    ta = TimeSeries.TimeArray(timestamps, data, colnames)

    forecast = CostCoefficient(get_label(forecasts[1]), break_points, ta)
    @debug "concatenated forecasts" forecast
    return forecast
end

function make_public_forecast(forecast::CostCoefficientInternal, data::TimeSeries.TimeArray)
    return CostCoefficient(get_label(forecast), get_break_points(forecast), data)
end

function make_internal_forecast(forecast::CostCoefficient, ts_data::TimeSeriesData)
    return CostCoefficientInternal(
        get_label(forecast),
        get_resolution(forecast),
        get_initial_time(forecast),
        get_break_points(forecast),
        get_uuid(ts_data),
        get_horizon(forecast),
    )
end

function forecast_external_to_internal(::Type{T}) where {T <: Forecast}
    if T <: Deterministic
        forecast_type = DeterministicInternal
    elseif T <: Probabilistic
        forecast_type = ProbabilisticInternal
    elseif T <: ScenarioBased
        forecast_type = ScenarioBasedInternal
    elseif T <: CostCoefficient
        forecast_type = CostCoefficientInternal
    else
        @assert false
    end

    return forecast_type
end

function forecast_internal_to_external(::Type{T}) where {T <: ForecastInternal}
    if T <: DeterministicInternal
        forecast_type = Deterministic
    elseif T <: ProbabilisticInternal
        forecast_type = Probabilistic
    elseif T <: ScenarioBasedInternal
        forecast_type = ScenarioBased
    elseif T <: CostCoefficientInternal
        forecast_type = CostCoefficient
    else
        @assert false
    end

    return forecast_type
end
