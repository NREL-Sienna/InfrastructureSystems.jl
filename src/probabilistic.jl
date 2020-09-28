"""
Constructs Probabilistic after constructing a TimeArray from initial_time and time_steps.
"""
function Probabilistic(
    name::String,
    resolution::Dates.Period,
    initial_time::Dates.DateTime,
    percentiles::Vector{Float64},
    time_steps::Int,
)
    data = TimeSeries.TimeArray(
        initial_time:resolution:(initial_time + resolution * (time_steps - 1)),
        ones(time_steps, length(percentiles)),
    )

    return Probabilistic(; name = name, percentiles = percentiles, data = data)
end

"""
Constructs Probabilistic forecast after constructing a TimeArray from initial_time and time_steps.
"""
# TODO: do we need this check still?
#function Probabilistic(
#                       name::String,
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
#    return Probabilistic(name, percentiles, data)
#end

function Probabilistic(
    name::String,
    resolution::Dates.Period,
    initial_time::Dates.DateTime,
    percentiles::Vector{Float64},  # percentiles for the probabilistic time_series
    data::TimeSeries.TimeArray,
)
    return Probabilistic(name = name, percentiles = percentiles, data = data)
end

function Probabilistic(
    ts_metadata::ProbabilisticMetadata,
    data::SortedDict{Dates.DateTime, Array},
)
    return Probabilistic(
        name = get_name(time_series),
        percentiles = get_percentiles(time_series),
        data = data,
        internal = InfrastructureSystemsInternal(get_time_series_uuid(ts_metadata)),
    )
end

function ProbabilisticMetadata(time_series::Probabilistic)
    return ProbabilisticMetadata(
        get_name(time_series),
        get_resolution(time_series),
        get_initial_time(time_series),
        get_interval(time_series),
        get_count(time_series),
        get_percentiles(time_series),
        get_uuid(time_series),
        get_horizon(time_series),
        get_scaling_factor_multiplier(time_series),
    )
end
