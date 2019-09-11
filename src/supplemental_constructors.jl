
"""Constructs Deterministic from a Component, label, and TimeArray."""
function Deterministic(component::Component, label::String, data::TimeSeries.TimeArray)
    resolution = get_resolution(data)
    initial_time = TimeSeries.timestamp(data)[1]
    Deterministic(component, label, Dates.Minute(resolution), initial_time, data)
end

"""Constructs Deterministic after constructing a TimeArray from initial_time and time_steps.
"""
function Deterministic(component::Component,
                       label::String,
                       resolution::Dates.Period,
                       initial_time::Dates.DateTime,
                       time_steps::Int)
    data = TimeSeries.TimeArray(
        initial_time : Dates.Hour(1) : initial_time + resolution * (time_steps-1),
        ones(time_steps)
    )
    return Deterministic(component, label, Dates.Minute(resolution), initial_time, data)
end

function Deterministic(component::Component,
                       label::AbstractString,
                       resolution::Dates.Period,
                       initial_time::Dates.DateTime,
                       data::TimeSeries.TimeArray,
                      )
    start_index = 1
    horizon = length(data)
    return Deterministic(component, label, resolution, initial_time, data, start_index,
                         horizon, InfrastructureSystemsInternal())
end

"""Constructs Probabilistic after constructing a TimeArray from initial_time and time_steps.
"""
function Probabilistic(component::Component,
                       label::String,
                       resolution::Dates.Period,
                       initial_time::Dates.DateTime,
                       quantiles::Vector{Float64},
                       time_steps::Int)

    data = TimeSeries.TimeArray(
        initial_time : Dates.Hour(1) : initial_time + resolution * (time_steps-1),
        ones(time_steps, length(quantiles))
    )

    return Probabilistic(component, label, Dates.Minute(resolution), initial_time,
                         quantiles, data)
end

"""Constructs Probabilistic Forecast after constructing a TimeArray from initial_time and time_steps.
"""
function Probabilistic(component::Component,
                       label::String,
                       quantiles::Vector{Float64},  # Quantiles for the probabilistic forecast
                       data::TimeSeries.TimeArray,
                      )

    if !(length(TimeSeries.colnames(data)) == length(quantiles))
        throw(DataFormatError(
            "The size of the provided quantiles and data columns is incosistent"))
    end
    initial_time = TimeSeries.timestamp(data)[1]
    resolution = get_resolution(data)

    return Probabilistic(component, label, Dates.Minute(resolution), initial_time,
                         quantiles, data)
end

function Probabilistic(component::Component,
                       label::String,
                       resolution::Dates.Period,
                       initial_time::Dates.DateTime,
                       quantiles::Vector{Float64},  # Quantiles for the probabilistic forecast
                       data::TimeSeries.TimeArray)
    start_index = 1
    horizon = length(data)
    return Probabilistic(component, label, resolution, initial_time, quantiles, data,
                         start_index, horizon, InfrastructureSystemsInternal())
end


"""Constructs ScenarioBased Forecast after constructing a TimeArray from initial_time and time_steps.
"""
function ScenarioBased(component::Component,
                       label::String,
                       resolution::Dates.Period,
                       initial_time::Dates.DateTime,
                       scenario_count::Int64,
                       time_steps::Int)

    data = TimeSeries.TimeArray(
        initial_time : Dates.Hour(1) : initial_time + resolution * (time_steps-1),
        ones(time_steps, scenario_count)
    )


    return ScenarioBased(component, label, Dates.Minute(resolution), initial_time, data)
end

"""Constructs ScenarioBased Forecast after constructing a TimeArray from initial_time and time_steps.
"""
function ScenarioBased(component::Component,
                       label::String,
                       data::TimeSeries.TimeArray,
                      )

    initial_time = TimeSeries.timestamp(data)[1]
    resolution = get_resolution(data)

    return ScenarioBased(component, label, Dates.Minute(resolution), initial_time,
                         data)
end

function ScenarioBased(component::Component,
                       label::String,
                       resolution::Dates.Period,
                       initial_time::Dates.DateTime,
                       data::TimeSeries.TimeArray)
    start_index = 1
    scenario_count = length(TimeSeries.colnames(data))
    horizon = length(data)
    return ScenarioBased(component, label, resolution, initial_time, scenario_count, data,
                            start_index, horizon, InfrastructureSystemsInternal())
end

