"""
    mutable struct Probabilistic <: Forecast
        name::String
        resolution::Dates.Period
        percentiles::Vector{Float64}
        data::Union{
            SortedDict{Dates.DateTime, Matrix{CONSTANT}},
            SortedDict{Dates.DateTime, Matrix{POLYNOMIAL}},
            SortedDict{Dates.DateTime, Matrix{PWL}},
        }
        scaling_factor_multiplier::Union{Nothing, Function}
        internal::InfrastructureSystemsInternal
    end

A Probabilistic forecast for a particular data field in a Component.

# Arguments
- `name::String`: user-defined name
- `resolution::Dates.Period`: forecast resolution
- `percentiles::Vector{Float64}`: Percentiles for the probabilistic forecast
- `data::Union{SortedDict{Dates.DateTime, Matrix{CONSTANT}}, SortedDict{Dates.DateTime, Matrix{POLYNOMIAL}}, SortedDict{Dates.DateTime, Matrix{PWL}}}`: timestamp - scalingfactor
- `scaling_factor_multiplier::Union{Nothing, Function}`: Applicable when the time series
  data are scaling factors. Called on the associated component to convert the values.
- `internal::InfrastructureSystemsInternal`
"""
mutable struct Probabilistic <: Forecast
    "user-defined name"
    name::String
    "timestamp - scalingfactor"
    data::Union{
        SortedDict{Dates.DateTime, Matrix{CONSTANT}},
        SortedDict{Dates.DateTime, Matrix{POLYNOMIAL}},
        SortedDict{Dates.DateTime, Matrix{PWL}},
    }
    "Percentiles for the probabilistic forecast"
    percentiles::Vector{Float64}
    "forecast resolution"
    resolution::Dates.Period
    "Applicable when the time series data are scaling factors. Called on the associated component to convert the values."
    scaling_factor_multiplier::Union{Nothing, Function}
    internal::InfrastructureSystemsInternal
end

function Probabilistic(;
    name,
    resolution,
    percentiles,
    data,
    scaling_factor_multiplier=nothing,
    normalization_factor=1.0,
    internal=InfrastructureSystemsInternal(),
)
    data = handle_normalization_factor(convert_data(data), normalization_factor)
    quantile_count = size(first(values(data)))[2]
    if quantile_count != length(percentiles)
        throw(
            ArgumentError(
                "The amount of elements in the data doesn't match the length of the percentiles",
            ),
        )
    end

    return Probabilistic(
        name,
        data,
        percentiles,
        resolution,
        scaling_factor_multiplier,
        internal,
    )
end

"""
Construct Probabilistic from a SortedDict of Arrays.

# Arguments
- `name::AbstractString`: user-defined name
- `input_data::AbstractDict{Dates.DateTime, Matrix{Float64}}`: time series data.
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
    input_data::AbstractDict,
    percentiles::Vector,
    resolution::Dates.Period;
    normalization_factor::NormalizationFactor=1.0,
    scaling_factor_multiplier::Union{Nothing, Function}=nothing,
)
    return Probabilistic(
        name=name,
        data=input_data,
        percentiles=percentiles,
        resolution=resolution,
        scaling_factor_multiplier=scaling_factor_multiplier,
        normalization_factor=normalization_factor,
        internal=InfrastructureSystemsInternal(),
    )
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
    normalization_factor::NormalizationFactor=1.0,
    scaling_factor_multiplier::Union{Nothing, Function}=nothing,
)
    data = SortedDict{Dates.DateTime, Matrix{Float64}}()
    resolution =
        TimeSeries.timestamp(first(values(input_data)))[2] -
        TimeSeries.timestamp(first(values(input_data)))[1]
    for (k, v) in input_data
        data[k] = TimeSeries.values(v)
    end

    return Probabilistic(
        name=name,
        data=data,
        percentiles=percentiles,
        resolution=resolution,
        normalization_factor=normalization_factor,
        scaling_factor_multiplier=scaling_factor_multiplier,
    )
end

"""
Construct Deterministic from RawTimeSeries.
"""
function Probabilistic(
    name::AbstractString,
    series_data::RawTimeSeries,
    percentiles::Vector,
    resolution::Dates.Period;
    normalization_factor::NormalizationFactor=1.0,
    scaling_factor_multiplier::Union{Nothing, Function}=nothing,
)
    return Probabilistic(
        name=name,
        data=series_data.data,
        percentiles=percentiles,
        resolution=resolution,
        normalization_factor=normalization_factor,
        scaling_factor_multiplier=scaling_factor_multiplier,
    )
end

function Probabilistic(ts_metadata::ProbabilisticMetadata, data::SortedDict)
    return Probabilistic(
        name=get_name(ts_metadata),
        percentiles=get_percentiles(ts_metadata),
        resolution=get_resolution(ts_metadata),
        data=data,
        scaling_factor_multiplier=get_scaling_factor_multiplier(ts_metadata),
        internal=InfrastructureSystemsInternal(get_time_series_uuid(ts_metadata)),
    )
end

function Probabilistic(info::TimeSeriesParsedInfo)
    return Probabilistic(
        name=info.name,
        data=info.data,
        percentiles=info.percentiles,
        resolution=info.resolution,
        normalization_factor=info.normalization_factor,
        scaling_factor_multiplier=info.scaling_factor_multiplier,
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

convert_data(data::AbstractDict{Dates.DateTime, Matrix{T}}) where {T} =
    SortedDict{Dates.DateTime, Matrix{CONSTANT}}(data...)
convert_data(data::AbstractDict{Dates.DateTime, Matrix{T}}) where {T <: Tuple} =
    SortedDict{Dates.DateTime, Matrix{POLYNOMIAL}}(data...)
convert_data(data::AbstractDict{Dates.DateTime, Matrix{Matrix{T}}}) where {T <: Tuple} =
    SortedDict{Dates.DateTime, Matrix{PWL}}(data...)
convert_data(
    data::Union{
        SortedDict{Dates.DateTime, Matrix{CONSTANT}},
        SortedDict{Dates.DateTime, Matrix{POLYNOMIAL}},
        SortedDict{Dates.DateTime, Matrix{PWL}},
    },
) = data

"""Get [`Probabilistic`](@ref) `name`."""
get_name(value::Probabilistic) = value.name
"""Get [`Probabilistic`](@ref) `resolution`."""
get_resolution(value::Probabilistic) = value.resolution
"""Get [`Probabilistic`](@ref) `percentiles`."""
get_percentiles(value::Probabilistic) = value.percentiles
"""Get [`Probabilistic`](@ref) `data`."""
get_data(value::Probabilistic) = value.data
"""Get [`Probabilistic`](@ref) `scaling_factor_multiplier`."""
get_scaling_factor_multiplier(value::Probabilistic) = value.scaling_factor_multiplier
"""Get [`Probabilistic`](@ref) `internal`."""
get_internal(value::Probabilistic) = value.internal

"""Set [`Probabilistic`](@ref) `name`."""
set_name!(value::Probabilistic, val) = value.name = val
"""Set [`Probabilistic`](@ref) `resolution`."""
set_resolution!(value::Probabilistic, val) = value.resolution = val
"""Set [`Probabilistic`](@ref) `percentiles`."""
set_percentiles!(value::Probabilistic, val) = value.percentiles = val
"""Set [`Probabilistic`](@ref) `data`."""
set_data!(value::Probabilistic, val) = value.data = val
"""Set [`Probabilistic`](@ref) `scaling_factor_multiplier`."""
set_scaling_factor_multiplier!(value::Probabilistic, val) =
    value.scaling_factor_multiplier = val
"""Set [`Probabilistic`](@ref) `internal`."""
set_internal!(value::Probabilistic, val) = value.internal = val

function get_array_for_hdf(forecast::Probabilistic)
    interval_count = get_count(forecast)
    percentile_count = length(get_percentiles(forecast))
    horizon = get_horizon(forecast)
    data = get_data(forecast)

    data_for_hdf = Array{Float64, 3}(undef, percentile_count, horizon, interval_count)
    for (ix, f) in enumerate(values(data))
        data_for_hdf[:, :, ix] = transpose(f)
    end
    return data_for_hdf
end

function get_horizon(forecast::Probabilistic)
    return size(first(values(get_data(forecast))))[1]
end

eltype_data(forecast::Probabilistic) = eltype_data_common(forecast)
get_count(forecast::Probabilistic) = get_count_common(forecast)
get_initial_times(forecast::Probabilistic) = get_initial_times_common(forecast)
get_initial_timestamp(forecast::Probabilistic) = get_initial_timestamp_common(forecast)
get_interval(forecast::Probabilistic) = get_interval_common(forecast)
get_window(f::Probabilistic, initial_time::Dates.DateTime; len=nothing) =
    get_window_common(f, initial_time; len=len)
iterate_windows(forecast::Probabilistic) = iterate_windows_common(forecast)
