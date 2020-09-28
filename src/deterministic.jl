"""
Construct Deterministic from a Dict of TimeArrays, DataFrames or Arrays.

# Arguments
- `name::AbstractString`: user-defined name
- `data::Union{Dict{Dates.DateTime, Any}, SortedDict.Dict{Dates.DateTime, Any}}`: time series data. The values in the dictionary should be TimeSeries.TimeArray or be able to be converted
- `normalization_factor::NormalizationFactor = 1.0`: optional normalization factor to apply
  to each data entry
- `scaling_factor_multiplier::Union{Nothing, Function} = nothing`: If the data are scaling
  factors then this function will be called on the component and applied to the data when
  [`get_time_series_array`](@ref) is called.
- `timestamp = :timestamp`: If the values are DataFrames is passed then this must be the column name that
  contains timestamps.
- `resolution = nothing : If the values are a Matrix or a Vector, then this must be the resolution of the forecast in Dates.Period`
"""
function Deterministic(
    name::AbstractString,
    data::Union{Dict{Dates.DateTime, Any}, SortedDict{Dates.DateTime, Any}};
    normalization_factor::NormalizationFactor = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
    resolution::Union{Dates.Period, Nothing} = nothing,
)
    for (k, v) in data
        if v isa DataFrames.DataFrame
            data[k] = Array(v)
        elseif v isa TimeSeries.TimeArray
            data[k] = TimeSeries.values(v)
            if resolution === nothing
                resolution = diff(TimeSeries.timestamp(v))[1]
            end
        else
            try
                data[k] = Vector{Float64}()
            catch e
                throw(ArgumentError("The values in the data dict are in an invalid format. Resulting error: $e"))
            end
        end
    end
    if resolution === nothing
        throw(ArgumentError("Need to pass resolution keyword argument or the data most be provided using TimeArrays"))
    end

    if !isa(data, SortedDict)
        data = SortedDict(data...)
    end

    initial_timestamp = first(keys(data))
    horizon = length(first(values(data)))
    data_ = handle_normalization_factor(data, normalization_factor)

    return Deterministic(
        name,
        initial_timestamp,
        horizon,
        resolution,
        data_,
        normalization_factor,
        scaling_factor_multiplier,
    )
end

"""
Construct Deterministic from RawTimeSeries.
"""
function Deterministic(
    name::AbstractString,
    series_data::RawTimeSeries,
    resolution::Dates.Period;
    normalization_factor::NormalizationFactor = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
)
    return Deterministic(
        name,
        series_data.data;
        normalization_factor = normalization_factor,
        scaling_factor = scaling_factor_multiplier,
        resolution = resolution,
    )
end

"""
Construct Deterministic from a CSV file. The file must have a column that is the name of the
component.

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
    component::InfrastructureSystemsComponent;
    resolution::Dates.Period,
    normalization_factor::NormalizationFactor = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
)
    component_name = get_name(component)
    raw_data = read_time_series(Deterministic, filename, component_name)
    return Deterministic(
        name,
        raw_data,
        resolution,
        normalization_factor,
        scaling_factor_multiplier,
    )
end

function Deterministic(
    ts_metadata::DeterministicMetadata,
    data::SortedDict{Dates.DateTime, Array},
    use_same_uuid::Bool,
)
    if use_same_uuid
        uuid = get_time_series_uuid(ts_metadata)
    else
        uuid = UUIDs.uuid4()
    end

    return Deterministic(
        name = get_name(ts_metadata),
        initial_timestamp = first(keys(data)),
        resolution = get_resolution(ts_metadata),
        horizon = length(first(values(data))),
        data = data,
        scaling_factor_multiplier = get_scaling_factor_multiplier(ts_metadata),
        internal = InfrastructureSystemsInternal(uuid),
    )
end

function Deterministic(info::TimeSeriesParsedInfo)
    return Deterministic(
        info.name,
        data,
        normalization_factor = info.normalization_factor,
        scaling_factor_multiplier = info.scaling_factor_multiplier,
        resolution = info.resolution,
    )
end

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

"""
Return the forecast window corresponsing to initial_time.
"""
function get_window(forecast::Deterministic, initial_time::Dates.DateTime)
    return TimeSeries.TimeArray(
        make_timestamps(forecast, initial_time),
        forecast.data[initial_time],
    )
end

"""
Return the forecast window corresponsing to interval index.
"""
function get_window(forecast::Deterministic, index::Int)
    return get_window(forecast, index_to_initial_time(forecast, index))
end

"""
Iterate over all forecast windows.
"""
function iterate_windows(forecast::Deterministic)
    return (get_window(forecast, it) for it in keys(forecast.data))
end

function get_array_for_hdf(forecast::Deterministic)
    return hcat(values(forecast.data)...)
end

"""
Creates a new Deterministic from an existing instance and a subset of data.
"""
function split_time_series(
    time_series::T,
    data::SortedDict{Dates.DateTime, Vector},
) where {T <: Deterministic}
    vals = []
    for (fname, ftype) in zip(fieldnames(T), fieldtypes(T))
        if ftype <: SortedDict{Dates.DateTime, Vector}
            val = data
        elseif ftype <: InfrastructureSystemsInternal
            # Need to create a new UUID.
            val = InfrastructureSystemsInternal()
        else
            val = getfield(time_series, fname)
        end

        push!(vals, val)
    end

    return T(vals...)
end
