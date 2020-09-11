
"""
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

function Deterministic(time_series::Vector{Deterministic})
    @assert !isempty(time_series)
    timestamps =
        collect(Iterators.flatten((TimeSeries.timestamp(get_data(x)) for x in time_series)))
    data = collect(Iterators.flatten((TimeSeries.values(get_data(x)) for x in time_series)))
    ta = TimeSeries.TimeArray(timestamps, data)

    time_series = Deterministic(get_label(time_series[1]), ta)
    @debug "concatenated time_series" time_series
    return time_series
end

# TODO: need to make concatenation constructors for Probabilistic

function make_time_series_data(
    time_series::DeterministicMetadata,
    data::TimeSeries.TimeArray,
)
    return Deterministic(get_label(time_series), data)
end

function make_time_series_metadata(time_series::Deterministic, ta::TimeArrayWrapper)
    return DeterministicMetadata(get_label(time_series), ta)
end

function DeterministicMetadata(label::AbstractString, data::TimeArrayWrapper)
    return DeterministicMetadata(
        label,
        get_resolution(data),
        get_initial_time(data),
        get_uuid(data),
        get_horizon(data),
    )
end

"""
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
Constructs Probabilistic TimeSeriesData after constructing a TimeArray from initial_time and time_steps.
"""
# TODO: do we need this check still?
#function Probabilistic(
#                       label::String,
#                       percentiles::Vector{Float64},  # percentiles for the probabilistic time_series
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
    percentiles::Vector{Float64},  # percentiles for the probabilistic time_series
    data::TimeSeries.TimeArray,
)
    return Probabilistic(label, percentiles, data)
end

function make_time_series_data(
    time_series::ProbabilisticMetadata,
    data::TimeSeries.TimeArray,
)
    return Probabilistic(get_label(time_series), get_percentiles(time_series), data)
end

function make_time_series_metadata(time_series::Probabilistic, ta::TimeArrayWrapper)
    return ProbabilisticMetadata(
        get_label(time_series),
        get_resolution(time_series),
        get_initial_time(time_series),
        get_percentiles(time_series),
        get_uuid(ta),
        get_horizon(time_series),
    )
end

function ScenarioBased(label::String, data::TimeSeries.TimeArray)
    initial_time = TimeSeries.timestamp(data)[1]
    resolution = get_resolution(data)
    scenario_count = length(TimeSeries.colnames(data))
    return ScenarioBased(label, scenario_count, data)
end

"""
Constructs ScenarioBased TimeSeriesData after constructing a TimeArray from initial_time and
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

function ScenarioBased(time_series::Vector{ScenarioBased})
    @assert !isempty(time_series)
    scenario_count = get_scenario_count(time_series[1])
    colnames = TimeSeries.colnames(get_data(time_series[1]))
    timestamps =
        collect(Iterators.flatten((TimeSeries.timestamp(get_data(x)) for x in time_series)))
    data = vcat((TimeSeries.values(get_data(x)) for x in time_series)...)
    ta = TimeSeries.TimeArray(timestamps, data, colnames)

    time_series = ScenarioBased(get_label(time_series[1]), ta)
    @debug "concatenated time_series" time_series
    return time_series
end

function make_time_series_data(
    time_series::ScenarioBasedMetadata,
    data::TimeSeries.TimeArray,
)
    return ScenarioBased(get_label(time_series), data)
end

function make_time_series_metadata(time_series::ScenarioBased, ta::TimeArrayWrapper)
    return ScenarioBasedMetadata(
        get_label(time_series),
        get_resolution(time_series),
        get_initial_time(time_series),
        get_scenario_count(time_series),
        get_uuid(ta),
        get_horizon(time_series),
    )
end

function PiecewiseFunction(label::String, data::TimeSeries.TimeArray)
    initial_time = TimeSeries.timestamp(data)[1]
    resolution = get_resolution(data)
    breakpoints = length(TimeSeries.colnames(data)) / 2
    return PiecewiseFunction(label, breakpoints, data)
end

"""
Constructs PiecewiseFunction TimeSeriesData after constructing a TimeArray from initial_time and
time_steps.
"""
function PiecewiseFunction(
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

    return PiecewiseFunction(label, break_points, data)
end

function PiecewiseFunction(time_series::Vector{PiecewiseFunction})
    @assert !isempty(time_series)
    break_points = get_break_points(time_series[1])
    colnames = TimeSeries.colnames(get_data(time_series[1]))
    timestamps =
        collect(Iterators.flatten((TimeSeries.timestamp(get_data(x)) for x in time_series)))
    data = vcat((TimeSeries.values(get_data(x)) for x in time_series)...)
    ta = TimeSeries.TimeArray(timestamps, data, colnames)

    time_series = PiecewiseFunction(get_label(time_series[1]), break_points, ta)
    @debug "concatenated time_series" time_series
    return time_series
end

get_columns(::Type{PiecewiseFunctionMetadata}, ta::TimeSeries.TimeArray) =
    TimeSeries.colnames(ta)

function make_time_series_data(
    time_series::PiecewiseFunctionMetadata,
    data::TimeSeries.TimeArray,
)
    return PiecewiseFunction(get_label(time_series), get_break_points(time_series), data)
end

function make_time_series_metadata(time_series::PiecewiseFunction, ta::TimeArrayWrapper)
    return PiecewiseFunctionMetadata(
        get_label(time_series),
        get_resolution(time_series),
        get_initial_time(time_series),
        get_break_points(time_series),
        get_uuid(ta),
        get_horizon(time_series),
    )
end

function time_series_data_to_metadata(::Type{T}) where {T <: TimeSeriesData}
    if T <: Deterministic
        time_series_type = DeterministicMetadata
    elseif T <: Probabilistic
        time_series_type = ProbabilisticMetadata
    elseif T <: ScenarioBased
        time_series_type = ScenarioBasedMetadata
    elseif T <: PiecewiseFunction
        time_series_type = PiecewiseFunctionMetadata
    else
        @assert false
    end

    return time_series_type
end

function time_series_data_to_metadata(::Type{T}) where {T <: TimeSeriesMetadata}
    if T <: DeterministicMetadata
        time_series_type = Deterministic
    elseif T <: ProbabilisticMetadata
        time_series_type = Probabilistic
    elseif T <: ScenarioBasedMetadata
        time_series_type = ScenarioBased
    elseif T <: PiecewiseFunctionMetadata
        time_series_type = PiecewiseFunction
    else
        @assert false
    end

    return time_series_type
end
