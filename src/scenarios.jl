function Scenarios(
    name::String,
    data::SortedDict{Dates.DateTime, TimeSeries.TimeArray},
    scaling_factor_multiplier = nothing,
)
    # TODO 1.0: consider determining fields from TimeArrays
    error("broken")
    initial_time = TimeSeries.timestamp(data)[1]
    resolution = get_resolution(data)
    scenario_count = length(TimeSeries.colnames(data))
    return Scenarios(
        name = name,
        scenario_count = scenario_count,
        data = data,
        scaling_factor_multiplier = scaling_factor_multiplier,
    )
end

"""
Constructs Scenarios forecast after constructing a TimeArray from initial_time and
time_steps.
"""
function Scenarios(
    name::String,
    resolution::Dates.Period,
    initial_time::Dates.DateTime,
    scenario_count::Int,
    time_steps::Int,
)
    data = TimeSeries.TimeArray(
        initial_time:resolution:(initial_time + resolution * (time_steps - 1)),
        ones(time_steps, scenario_count),
    )

    return Scenarios(name, data)
end

function Scenarios(time_series::Vector{Scenarios})
    @assert !isempty(time_series)
    scenario_count = get_scenario_count(time_series[1])
    colnames = TimeSeries.colnames(get_data(time_series[1]))
    timestamps =
        collect(Iterators.flatten((TimeSeries.timestamp(get_data(x)) for x in time_series)))
    data = vcat((TimeSeries.values(get_data(x)) for x in time_series)...)
    ta = TimeSeries.TimeArray(timestamps, data, colnames)

    time_series =
        Scenarios(get_name(time_series[1]), ta, time_series[1].scaling_factor_multiplier)
    @debug "concatenated time_series" time_series
    return time_series
end

function Scenarios(ts_metadata::ScenariosMetadata, data::Array)
    return Scenarios(
        name = get_name(ts_metadata),
        scenario_count = get_scenario_count(ts_metadata),
        data = data,
        internal = InfrastructureSystemsInternal(get_time_series_uuid(ts_metadata)),
    )
end

function ScenariosMetadata(time_series::Scenarios)
    return ScenariosMetadata(
        get_name(time_series),
        get_resolution(time_series),
        get_initial_timestamp(time_series),
        get_interval(time_series),
        get_scenario_count(time_series),
        get_count(time_series),
        get_uuid(time_series),
        get_horizon(time_series),
        get_scaling_factor_multiplier(time_series),
    )
end
