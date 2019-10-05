
function make_public_forecast(forecast::ForecastInternal, d::TimeSeriesData)
    error("$(typeof(forecast)) must implement make_public_forecast")
end

function make_internal_forecast(forecast::Forecast)
    error("$(typeof(forecast)) must implement make_internal_forecast")
end

"""Constructs Deterministic after constructing a TimeArray from initial_time and time_steps.
"""
# TODO DT: if this is still needed then the TimeArray has to be created by SystemData so
# that it can be stored in TimeSeriesStorage.
#function Deterministic(label::String,
#                       resolution::Dates.Period,
#                       initial_time::Dates.DateTime,
#                       time_steps::Int)
#    data = TimeSeries.TimeArray(
#        initial_time : Dates.Hour(1) : initial_time + resolution * (time_steps-1),
#        ones(time_steps)
#    )
#    return Deterministic(label, Dates.Minute(resolution), initial_time, data)
#end

# TODO DT: Call site has to calculate initial_time and resolution.
#function Deterministic(label::AbstractString,
#                       resolution::Dates.Period,
#                       initial_time::Dates.DateTime,
#                       time_series_uuid::TimeSeries.TimeArray,
#                      )
#    start_index = 1
#    horizon = length(data)
#    return Deterministic(label, resolution, initial_time, data, start_index,
#                         horizon, InfrastructureSystemsInternal())
#end

function make_public_forecast(forecast::DeterministicInternal, data::TimeSeries.TimeArray)
    return Deterministic(get_label(forecast), data)
end

function make_internal_forecast(forecast::Deterministic, ts_data::TimeSeriesData)
    return DeterministicInternal(get_label(forecast), ts_data)
end

function DeterministicInternal(label::AbstractString, data::TimeSeriesData)
    return DeterministicInternal(label,
                                 get_resolution(data),
                                 get_initial_time(data),
                                 get_uuid(data),
                                 get_horizon(data))
end

"""Constructs Probabilistic after constructing a TimeArray from initial_time and time_steps.
"""
function ProbabilisticInternal(label::String,
                       resolution::Dates.Period,
                       initial_time::Dates.DateTime,
                       percentiles::Vector{Float64},
                       time_steps::Int)

    data = TimeSeries.TimeArray(
        initial_time : Dates.Hour(1) : initial_time + resolution * (time_steps-1),
        ones(time_steps, length(percentiles))
    )

    return ProbabilisticInternal(label, Dates.Minute(resolution), initial_time, percentiles, data)
end

"""Constructs Probabilistic Forecast after constructing a TimeArray from initial_time and time_steps.
"""
function ProbabilisticInternal(label::String,
                       percentiles::Vector{Float64},  # percentiles for the probabilistic forecast
                       data::TimeSeries.TimeArray,
                      )

    if !(length(TimeSeries.colnames(data)) == length(percentiles))
        throw(DataFormatError(
            "The size of the provided percentiles and data columns is incosistent"))
    end
    initial_time = TimeSeries.timestamp(data)[1]
    resolution = get_resolution(data)

    return ProbabilisticInternal(label, Dates.Minute(resolution), initial_time,
                         percentiles, data)
end

function ProbabilisticInternal(label::String,
                       resolution::Dates.Period,
                       initial_time::Dates.DateTime,
                       percentiles::Vector{Float64},  # percentiles for the probabilistic forecast
                       data::TimeSeries.TimeArray)
    horizon = length(data)
    return ProbabilisticInternal(horizon, InfrastructureSystemsInternal())
end


function make_public_forecast(forecast::ProbabilisticInternal, data::TimeSeries.TimeArray)
    return Probabilistic(get_label(forecast), get_percentiles(forecast), data)
end


function make_internal_forecast(forecast::Probabilistic, ts_data::TimeSeriesData)
    return ProbabilisticInternal(get_label(forecast), get_scenario_count(forecast), ts_data)
end

"""Constructs ScenarioBased Forecast after constructing a TimeArray from initial_time and time_steps.
"""
function ScenarioBased(label::String,
                       resolution::Dates.Period,
                       initial_time::Dates.DateTime,
                       scenario_count::Int64,
                       time_steps::Int)

    data = TimeSeries.TimeArray(
        initial_time : Dates.Hour(1) : initial_time + resolution * (time_steps-1),
        ones(time_steps, scenario_count)
    )


    return ScenarioBased(label, Dates.Minute(resolution), initial_time, data)
end

"""Constructs ScenarioBased Forecast after constructing a TimeArray from initial_time and time_steps.
"""
function ScenarioBased(label::String, data::TimeSeries.TimeArray)

    initial_time = TimeSeries.timestamp(data)[1]
    resolution = get_resolution(data)

    return ScenarioBased(label, Dates.Minute(resolution), initial_time, data)
end

function ScenarioBased(label::String,
                       resolution::Dates.Period,
                       initial_time::Dates.DateTime,
                       data::TimeSeries.TimeArray)
    scenario_count = length(TimeSeries.colnames(data))
    horizon = length(data)
    return ScenarioBased(label, resolution, initial_time, scenario_count, data,
                         horizon, InfrastructureSystemsInternal())
end

function make_public_forecast(forecast::ScenarioBasedInternal, data::TimeSeries.TimeArray)
    return ScenarioBased(get_label(forecast), data)
end

function make_internal_forecast(forecast::ScenarioBased, ts_data::TimeSeriesData)
    return ScenarioBasedInternal(get_label(forecast), get_scenario_count(forecast), ts_data)
end
