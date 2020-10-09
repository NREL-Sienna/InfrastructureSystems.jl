"""
A deterministic forecast for a particular data field in a Component.
"""
mutable struct Deterministic <: Forecast
    forecast::Union{DeterministicStandard, DeterministicSingleTimeSeries}
end

#=
#  Design Note
#  The Deterministic struct abstracts the two possible types of deterministic forecasts.
#  1. DeterministicStandard stores vectors of forecasted values by incrementing initial time
#     where each vector is of length `horizon`.
#  2. DeterministicSingleTimeSeries stores a single vector of values by wrapping a
#     SingleTimeSeries instance. It can be viewed as a forecast by taking slices of the
#     vector at incrementing offsets.
#
#  Both types implement the same interfaces, and so they are interchangeable for the user.
#  Selection of one type vs the other will happen during the parsing process based on the
#  type of input data.
#
#  The Deterministic abstraction makes it so the normal user (modeller) will not know or
#  care what the underlying type is.
#
#  A consequence of this abstraction is that the Deterministic struct must implement every
#  constructor and method that the subtypes implement and forward to them. This causes
#  quite a bit of duplication. A different solution would have prevented that. We could
#  have created an AbstractDeterministic and made DeterministicStandard and
#  DeterministicSingleTimeSeries subtypes of it, and then returned those specific types to
#  the user. The team decided that this was overly complicated for the target users.
=#

function Deterministic(
    name::AbstractString,
    resolution::Dates.Period,
    data::SortedDict{Dates.DateTime, Vector},
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
)
    return Deterministic(DeterministicStandard(
        name,
        resolution,
        data,
        scaling_factor_multiplier,
    ))
end

"""
Construct Deterministic from a Dict of TimeArrays.

# Arguments
- `name::AbstractString`: user-defined name
- `data::AbstractDict{Dates.DateTime, TimeSeries.TimeArray}`: time series data.
- `normalization_factor::NormalizationFactor = 1.0`: optional normalization factor to apply
  to each data entry
- `scaling_factor_multiplier::Union{Nothing, Function} = nothing`: If the data are scaling
  factors then this function will be called on the component and applied to the data when
  [`get_time_series_array`](@ref) is called.
- `timestamp = :timestamp`: If the values are DataFrames is passed then this must be the
  column name that contains timestamps.
"""
function Deterministic(
    name::AbstractString,
    data::AbstractDict{Dates.DateTime, <:TimeSeries.TimeArray};
    normalization_factor::NormalizationFactor = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
)
    return Deterministic(DeterministicStandard(
        name,
        data;
        normalization_factor = normalization_factor,
        scaling_factor_multiplier = scaling_factor_multiplier,
    ))
end

"""
Construct Deterministic from a Dict of collections of data.

# Arguments
- `name::AbstractString`: user-defined name
- `data::AbstractDict{Dates.DateTime, Any}`: time series data. The values
  in the dictionary should be able to be converted to Float64
- `resolution::Dates.Period`: The resolution of the forecast in Dates.Period`
- `normalization_factor::NormalizationFactor = 1.0`: optional normalization factor to apply
  to each data entry
- `scaling_factor_multiplier::Union{Nothing, Function} = nothing`: If the data are scaling
  factors then this function will be called on the component and applied to the data when
  [`get_time_series_array`](@ref) is called.
"""
function Deterministic(
    name::AbstractString,
    data::AbstractDict{Dates.DateTime, <:Any},
    resolution::Dates.Period;
    normalization_factor::NormalizationFactor = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
)
    return Deterministic(DeterministicStandard(
        name,
        data,
        resolution;
        normalization_factor = normalization_factor,
        scaling_factor_multiplier = scaling_factor_multiplier,
    ))
end

"""
Construct DeterministicStandard from a CSV file. The first column must be a timestamp in
DateTime format and the columns the values in the forecast window.

# Arguments
- `name::AbstractString`: user-defined name
- `filename::AbstractString`: name of CSV file containing data
- `component::InfrastructureSystemsComponent`: component associated with the data
- `normalization_factor::NormalizationFactor = 1.0`: optional normalization factor to apply
  to each data entry
- `scaling_factor_multiplier::Union{Nothing, Function} = nothing`: If the data are scaling
  factors then this function will be called on the component and applied to the data when
  [`get_time_series_array`](@ref) is called.
"""
function Deterministic(
    name::AbstractString,
    filename::AbstractString,
    component::InfrastructureSystemsComponent,
    resolution::Dates.Period;
    normalization_factor::NormalizationFactor = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
)
    return Deterministic(DeterministicStandard(
        name,
        filename,
        component,
        resolution;
        normalization_factor = normalization_factor,
        scaling_factor_multiplier = scaling_factor_multiplier,
    ))
end

function Deterministic(;
    name::AbstractString,
    resolution::Dates.Period,
    data,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
    single_time_series = nothing,
    internal = InfrastructureSystemsInternal(),
)
    if single_time_series === nothing
        return Deterministic(DeterministicStandard(
            name = name,
            resolution = resolution,
            data = data,
            scaling_factor_multiplier = scaling_factor_multiplier,
            internal = internal,
        ))
    end

    return Deterministic(DeterministicSingleTimeSeries(
        single_time_series = single_time_series,
        initial_timestamp = initial_timestamp,
        interval = interval,
        count = count,
        horizon = horizon,
        internal = internal,
    ))
end

"""
Construct a Deterministic from a SingleTimeSeries.
"""
function Deterministic(ts::SingleTimeSeries, count, horizon, initial_timestamp, interval)
    return Deterministic(DeterministicSingleTimeSeries(
        single_time_series = ts,
        count = count,
        horizon = horizon,
        initial_timestamp = initial_timestamp,
        interval = interval,
    ))
end

"""
Construct Deterministic from RawTimeSeries.
"""
function Deterministic(
    name::AbstractString,
    data::RawTimeSeries,
    resolution::Dates.Period;
    normalization_factor::NormalizationFactor = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
)
    return Deterministic(DeterministicStandard(
        name,
        data,
        resolution;
        normalization_factor = normalization_factor,
        scaling_factor_multiplier = scaling_factor_multiplier,
    ))
end

function Deterministic(
    ts_metadata::DeterministicMetadata,
    data::SortedDict{Dates.DateTime, Array},
)
    return Deterministic(
        name = get_name(ts_metadata),
        resolution = get_resolution(ts_metadata),
        data = data,
        scaling_factor_multiplier = get_scaling_factor_multiplier(ts_metadata),
        internal = InfrastructureSystemsInternal(get_time_series_uuid(ts_metadata)),
    )
end

function Deterministic(info::TimeSeriesParsedInfo)
    return Deterministic(
        info.name,
        info.data,
        info.resolution;
        normalization_factor = info.normalization_factor,
        scaling_factor_multiplier = info.scaling_factor_multiplier,
    )
end

"""
Construct a new Deterministic from an existing instance and a subset of data.
"""
function Deterministic(forecast::Deterministic, data::SortedDict{Dates.DateTime, Vector})
    type = typeof(forecast.forecast)
    vals = Dict{Symbol, Any}()
    for (fname, ftype) in zip(fieldnames(type), fieldtypes(type))
        if ftype <: SortedDict{Dates.DateTime, Vector}
            val = data
        elseif ftype <: InfrastructureSystemsInternal
            # Need to create a new UUID.
            val = InfrastructureSystemsInternal()
        else
            val = getfield(forecast.forecast, fname)
        end

        vals[fname] = val
    end

    return Deterministic(; vals...)
end

Base.length(f::Deterministic) = length(f.forecast)
get_array_for_hdf(f::Deterministic) = get_array_for_hdf(f.forecast)
get_count(f::Deterministic) = get_count(f.forecast)
get_horizon(f::Deterministic) = get_horizon(f.forecast)
get_initial_timestamp(f::Deterministic) = get_initial_timestamp(f.forecast)
get_internal(f::Deterministic) = get_internal(f.forecast)
get_interval(f::Deterministic) = get_interval(f.forecast)
get_name(f::Deterministic) = get_name(f.forecast)
get_resolution(f::Deterministic) = get_resolution(f.forecast)
get_scaling_factor_multiplier(f::Deterministic) = get_scaling_factor_multiplier(f.forecast)
get_window(f::Deterministic, it::Dates.DateTime; len = nothing) =
    get_window(f.forecast, it; len = len)
iterate_windows(f::Deterministic) = iterate_windows(f.forecast)

function DeterministicMetadata(ts::Deterministic)
    return DeterministicMetadata(
        get_name(ts),
        get_resolution(ts),
        get_initial_timestamp(ts),
        get_interval(ts),
        get_count(ts),
        get_uuid(ts),
        get_horizon(ts),
        get_scaling_factor_multiplier(ts),
    )
end

function deserialize_deterministic_from_single_time_series(
    storage::TimeSeriesStorage,
    ts_metadata::DeterministicMetadata,
    rows,
    columns,
    last_index,
)
    @debug "deserializing a SingleTimeSeries"
    horizon = get_horizon(ts_metadata)
    interval = get_interval(ts_metadata)
    resolution = get_resolution(ts_metadata)
    if length(rows) != horizon
        throw(ArgumentError("Transforming SingleTimeSeries to Deterministic requires a full horizon: $rows"))
    end

    sts_rows =
        _translate_deterministic_offsets(horizon, interval, resolution, columns, last_index)
    sts = deserialize_time_series(
        SingleTimeSeries,
        storage,
        SingleTimeSeriesMetadata(ts_metadata),
        sts_rows,
        UnitRange(1, 1),
    )
    initial_timestamp =
        get_initial_timestamp(ts_metadata) + (columns.start - 1) * get_interval(ts_metadata)
    return Deterministic(sts, length(columns), horizon, initial_timestamp, interval)
end

function _translate_deterministic_offsets(
    horizon,
    interval,
    resolution,
    columns,
    last_index,
)
    interval = Dates.Millisecond(interval)
    interval_offset = Int(interval / resolution)
    s_index = (columns.start - 1) * interval_offset + 1
    e_index = (columns.stop - 1) * interval_offset + horizon
    @debug "translated offsets" horizon columns s_index e_index last_index
    @assert s_index <= last_index
    @assert e_index <= last_index
    return UnitRange(s_index, e_index)
end
