
"""Constructs Deterministic from a InfrastructureSystemsType, label, and TimeArray."""
function Deterministic(component::InfrastructureSystemsType, label::String, data::TimeSeries.TimeArray)
    resolution = get_resolution(data)
    initial_time = TimeSeries.timestamp(data)[1]
    Deterministic(component, label, Dates.Minute(resolution), initial_time, data)
end

"""Constructs Deterministic after constructing a TimeArray from initial_time and time_steps.
"""
function Deterministic(component::InfrastructureSystemsType,
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

function Deterministic(component::InfrastructureSystemsType,
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
function Probabilistic(component::InfrastructureSystemsType,
                       label::String,
                       resolution::Dates.Period,
                       initial_time::Dates.DateTime,
                       percentiles::Vector{Float64},
                       time_steps::Int)

    data = TimeSeries.TimeArray(
        initial_time : Dates.Hour(1) : initial_time + resolution * (time_steps-1),
        ones(time_steps, length(percentiles))
    )

    return Probabilistic(component, label, Dates.Minute(resolution), initial_time,
                         percentiles, data)
end

"""Constructs Probabilistic Forecast after constructing a TimeArray from initial_time and time_steps.
"""
function Probabilistic(component::InfrastructureSystemsType,
                       label::String,
                       percentiles::Vector{Float64},  # percentiles for the probabilistic forecast
                       data::TimeSeries.TimeArray,
                      )

    if !(length(TimeSeries.colnames(data)) == length(percentiles))
        throw(DataFormatError(
            "The size of the provided percentiles and data columns is incosistent"))
    end
    initial_time = TimeSeries.timestamp(data)[1]
    resolution = get_resolution(data)

    return Probabilistic(component, label, Dates.Minute(resolution), initial_time,
                         percentiles, data)
end

function Probabilistic(component::InfrastructureSystemsType,
                       label::String,
                       resolution::Dates.Period,
                       initial_time::Dates.DateTime,
                       percentiles::Vector{Float64},  # percentiles for the probabilistic forecast
                       data::TimeSeries.TimeArray)
    start_index = 1
    horizon = length(data)
    return Probabilistic(component, label, resolution, initial_time, percentiles, data,
                         start_index, horizon, InfrastructureSystemsInternal())
end


"""Constructs ScenarioBased Forecast after constructing a TimeArray from initial_time and time_steps.
"""
function ScenarioBased(component::InfrastructureSystemsType,
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
function ScenarioBased(component::InfrastructureSystemsType,
                       label::String,
                       data::TimeSeries.TimeArray,
                      )

    initial_time = TimeSeries.timestamp(data)[1]
    resolution = get_resolution(data)

    return ScenarioBased(component, label, Dates.Minute(resolution), initial_time,
                         data)
end

function ScenarioBased(component::InfrastructureSystemsType,
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
