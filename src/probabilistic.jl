"""
Construct Probabilistic from a SortedDict of Arrays.

# Arguments
- `name::AbstractString`: user-defined name
- `input_data::AbstractDict{Dates.DateTime, Vector{Float64}}`: time series data.
- `percentiles`: Percentiles represented in the probabilistic forecast
- `resolution::Dates.Period`: The resolution of the forecast in Dates.Period`
- `normalization_factor::NormalizationFactor = 1.0`: optional normalization factor to apply
  to each data entry
- `scaling_factor_multiplier::Union{Nothing, Function} = nothing`: If the data are scaling
  factors then this function will be called on the component and applied to the data when
  [`get_time_series_array`](@ref) is called.
"""
function Probabilistic(
    name::AbstractString,
    input_data::AbstractDict{Dates.DateTime, <:Array},
    percentiles::Vector{Float64};
    resolution::Dates.Period,
    normalization_factor::NormalizationFactor = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
)
    if !isa(input_data, SortedDict)
        input_data = SortedDict(input_data...)
    end
    data = handle_normalization_factor(input_data, normalization_factor)
    initial_timestamp = first(keys(data))
    horizon, quantile_count = size(first(values(data)))
    if quantile_count != length(percentiles)
        throw(ArgumentError("The amount of elements in the data doesn't match the length of the percentiles"))
    end
    data = handle_normalization_factor(input_data, normalization_factor)


    return Probabilistic(name,
                        initial_timestamp,
                        horizon,
                        resolution,
                        percentiles,
                        data,
                        scaling_factor_multiplier)
end

"""
Construct Probabilistic from a Dict of TimeArrays.

# Arguments
- `name::AbstractString`: user-defined name
- `input_data::AbstractDict{Dates.DateTime, TimeSeries.TimeArray}`: time series data.
- `percentiles`: Percentiles represented in the probabilistic forecast
- `normalization_factor::NormalizationFactor = 1.0`: optional normalization factor to apply
  to each data entry
- `scaling_factor_multiplier::Union{Nothing, Function} = nothing`: If the data are scaling
  factors then this function will be called on the component and applied to the data when
  [`get_time_series_array`](@ref) is called.
- `timestamp = :timestamp`: If the values are DataFrames is passed then this must be the column name that
  contains timestamps.
"""
function Probabilistic(
    name::AbstractString,
    input_data::AbstractDict{Dates.DateTime, <:TimeSeries.TimeArray},
    percentiles::Vector{Float64};
    normalization_factor::NormalizationFactor = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
)
    data = SortedDict{Dates.DateTime, Vector{Float64}}()
    resolution =
        TimeSeries.timestamp(first(values(input_data)))[2] -
        TimeSeries.timestamp(first(values(input_data)))[1]
    for (k, v) in input_data
        data[k] = TimeSeries.values(v)
    end

    return Probabilistic(
        name,
        data,
        percentiles;
        resolution = resolution,
        normalization_factor = normalization_factor,
        scaling_factor_multiplier = scaling_factor_multiplier,
    )
end


"""
Construct Deterministic from RawTimeSeries.
"""
function Probabilistic(
    name::AbstractString,
    series_data::RawTimeSeries,
    percentiles::Vector{Float64};
    resolution::Dates.Period,
    normalization_factor::NormalizationFactor = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
)
    return Probabilistic(
        name,
        series_data.data,
        percentiles;
        resolution = resolution,
        normalization_factor = normalization_factor,
        scaling_factor_multiplier = scaling_factor_multiplier,
    )
end

function Probabilistic(
    ts_metadata::ProbabilisticMetadata,
    data::SortedDict{Dates.DateTime, Array},
)
    return Probabilistic(
            name = get_name(ts_metadata),
            percentiles = get_percentiles(ts_metadata),
            initial_timestamp = first(keys(data)),
            resolution = get_resolution(ts_metadata),
            horizon = length(first(values(data))),
            data = data,
            scaling_factor_multiplier = get_scaling_factor_multiplier(ts_metadata),
            internal = InfrastructureSystemsInternal(get_time_series_uuid(ts_metadata)),
    )
end

function Probabilistic(info::TimeSeriesParsedInfo)
    return Probabilistic(
        info.name,
        info.data,
        info.percentiles;
        resolution = info.resolution,
        normalization_factor = info.normalization_factor,
        scaling_factor_multiplier = info.scaling_factor_multiplier,
    )
end

function ProbabilisticMetadata(time_series::Probabilistic)
    return ProbabilisticMetadata(
        get_name(time_series),
        get_initial_timestamp(time_series),
        get_resolution(time_series),
        get_interval(time_series),
        get_count(time_series),
        get_percentiles(time_series),
        get_uuid(time_series),
        get_horizon(time_series),
        get_scaling_factor_multiplier(time_series),
    )
end

function get_array_for_hdf(forecast::Probabilistic)
    interval_count = get_count(forecast)
    percentile_count = length(get_percentiles(forecast))
    horizon = get_horizon(forecast)
    data = get_data(forecast)
    data_for_hdf = Array{Float64, 3}(undef, interval_count, horizon, percentile_count)
    for (ix, f) in enumerate(values(data))
        data_for_hdf[ix, :, :] = f
    end
    return data_for_hdf
end