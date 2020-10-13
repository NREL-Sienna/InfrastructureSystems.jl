function Deterministic(
    name::AbstractString,
    input_data::AbstractDict{Dates.DateTime, Vector{Float64}},
    resolution::Dates.Period;
    normalization_factor::NormalizationFactor = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
)
    if !isa(input_data, SortedDict)
        input_data = SortedDict(input_data...)
    end
    data = handle_normalization_factor(input_data, normalization_factor)
    return Deterministic(name, resolution, data, scaling_factor_multiplier)
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
    input_data::AbstractDict{Dates.DateTime, <:TimeSeries.TimeArray};
    normalization_factor::NormalizationFactor = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
)
    data_type = eltype(TimeSeries.values(first(values(input_data))))
    data = SortedDict{Dates.DateTime, Vector{data_type}}()
    resolution =
        TimeSeries.timestamp(first(values(input_data)))[2] -
        TimeSeries.timestamp(first(values(input_data)))[1]
    for (k, v) in input_data
        if length(size(v)) > 1
            throw(ArgumentError("TimeArray with timestamp $k has more than one column)"))
        end
        data[k] = TimeSeries.values(v)
    end

    return Deterministic(
        name,
        data,
        resolution;
        normalization_factor = normalization_factor,
        scaling_factor_multiplier = scaling_factor_multiplier,
    )
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
    input_data::AbstractDict{Dates.DateTime, <:Any},
    resolution::Dates.Period;
    normalization_factor::NormalizationFactor = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
)
    data = SortedDict{Dates.DateTime, Vector{Float64}}()
    for (k, v) in input_data
        try
            data[k] = Float64[i for i in v]
        catch e
            @error("The forecast data provided $(eltype(input_data)) can't be converted to Vector{Float64}")
            rethrow()
        end
    end
    @assert !isempty(data)

    return Deterministic(
        name,
        data,
        resolution;
        normalization_factor = normalization_factor,
        scaling_factor_multiplier = scaling_factor_multiplier,
    )
end

function Deterministic(
    name::AbstractString,
    input_data::AbstractDict{Dates.DateTime, <:Vector},
    resolution::Dates.Period;
    normalization_factor::NormalizationFactor = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
)
    if !isa(input_data, SortedDict)
        input_data = SortedDict(input_data...)
    end
    @assert !isempty(input_data)

    return Deterministic(name, resolution, input_data, scaling_factor_multiplier)
end

"""
Construct Deterministic from a CSV file. The first column must be a timestamp in
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
    component_name = get_name(component)
    raw_data = read_time_series(Deterministic, filename, component_name)
    return Deterministic(
        name,
        raw_data,
        resolution;
        normalization_factor = normalization_factor,
        scaling_factor_multiplier = scaling_factor_multiplier,
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
        series_data.data,
        resolution;
        normalization_factor = normalization_factor,
        scaling_factor_multiplier = scaling_factor_multiplier,
    )
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
    vals = Dict{Symbol, Any}()
    for (fname, ftype) in zip(fieldnames(Deterministic), fieldtypes(Deterministic))
        if ftype <: SortedDict{Dates.DateTime, Vector}
            val = data
        elseif ftype <: InfrastructureSystemsInternal
            # Need to create a new UUID.
            val = InfrastructureSystemsInternal()
        else
            val = getfield(forecast, fname)
        end

        vals[fname] = val
    end

    return Deterministic(; vals...)
end

function get_array_for_hdf(forecast::Deterministic)
    data_type = eltype(first(values(forecast.data)))
    return transform_array_for_hdf(forecast.data, data_type)
end

function get_horizon(forecast::Deterministic)
    return length(first(values(get_data(forecast))))
end

function make_time_array(forecast::Deterministic)
    # Artificial limitation to reduce scope.
    @assert get_count(forecast) == 1
    timestamps = range(
        get_initial_timestamp(forecast);
        step = get_resolution(forecast),
        length = get_horizon(forecast),
    )
    data = first(values(get_data(forecast)))
    return TimeSeries.TimeArray(timestamps, data)
end
