"""
Construct SingleTimeSeries from a TimeArray or DataFrame.

# Arguments
- `name::AbstractString`: user-defined name
- `data::Union{TimeSeries.TimeArray, DataFrames.DataFrame}`: time series data
- `normalization_factor::NormalizationFactor = 1.0`: optional normalization factor to apply
  to each data entry
- `scaling_factor_multiplier::Union{Nothing, Function} = nothing`: If the data are scaling
  factors then this function will be called on the component and applied to the data when
  [`get_time_series_array`](@ref) is called.
- `timestamp = :timestamp`: If a DataFrame is passed then this must be the column name that
  contains timestamps.
"""
function SingleTimeSeries(
    name::AbstractString,
    data::Union{TimeSeries.TimeArray, DataFrames.DataFrame};
    normalization_factor::NormalizationFactor = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
    timestamp = :timestamp,
)
    if data isa DataFrames.DataFrame
        ta = TimeSeries.TimeArray(data; timestamp = timestamp)
    elseif data isa TimeSeries.TimeArray
        ta = data
    else
        error("fatal: $(typeof(data))")
    end

    ta = handle_normalization_factor(ta, normalization_factor)
    return SingleTimeSeries(name, ta, scaling_factor_multiplier)
end

"""
Construct SingleTimeSeries from a CSV file. The file must have a column that is the name of the
component.

# Arguments
- `name::AbstractString`: user-defined name
- `filename::AbstractString`: name of CSV file containing data
- `normalization_factor::NormalizationFactor = 1.0`: optional normalization factor to apply
  to each data entry
- `scaling_factor_multiplier::Union{Nothing, Function} = nothing`: If the data are scaling
  factors then this function will be called on the component and applied to the data when
  [`get_time_series_array`](@ref) is called.
"""
function SingleTimeSeries(
    name::AbstractString,
    filename::AbstractString,
    component::InfrastructureSystemsComponent;
    normalization_factor::NormalizationFactor = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
)
    component_name = get_name(component)
    ta = read_time_series(filename, component_name)
    ta = handle_normalization_factor(ta[Symbol(component_name)], normalization_factor)
    return SingleTimeSeries(name, ta, scaling_factor_multiplier)
end

"""
Construct SingleTimeSeries after constructing a TimeArray from `initial_time` and
`time_steps`.
"""
function SingleTimeSeries(
    name::String,
    resolution::Dates.Period,
    initial_time::Dates.DateTime,
    time_steps::Int,
)
    data = TimeSeries.TimeArray(
        initial_time:resolution:(initial_time + resolution * (time_steps - 1)),
        ones(time_steps),
    )
    return SingleTimeSeries(; name = name, data = data)
end

function SingleTimeSeries(time_series::Vector{SingleTimeSeries})
    @assert !isempty(time_series)
    timestamps =
        collect(Iterators.flatten((TimeSeries.timestamp(get_data(x)) for x in time_series)))
    data = collect(Iterators.flatten((TimeSeries.values(get_data(x)) for x in time_series)))
    ta = TimeSeries.TimeArray(timestamps, data)

    time_series = SingleTimeSeries(
        name = get_name(time_series[1]),
        data = ta,
        scaling_factor_multiplier = time_series[1].scaling_factor_multiplier,
    )
    @debug "concatenated time_series" time_series
    return time_series
end

function SingleTimeSeries(ts_metadata::SingleTimeSeriesMetadata, data::TimeSeries.TimeArray)
    return SingleTimeSeries(
        get_name(ts_metadata),
        data,
        get_scaling_factor_multiplier(ts_metadata),
        InfrastructureSystemsInternal(get_time_series_uuid(ts_metadata)),
    )
end

function SingleTimeSeriesMetadata(ts::SingleTimeSeries)
    return SingleTimeSeriesMetadata(
        get_name(ts),
        get_resolution(ts),
        get_initial_time(ts),
        get_uuid(ts),
        length(ts),
        get_scaling_factor_multiplier(ts),
    )
end

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
    timestamp = :timestamp,
    resolution::Union{Dates.Period, Nothing} = nothing,
)
    for (k, v) in data
        if v isa DataFrames.DataFrame
            data[k] = TimeSeries.TimeArray(v; timestamp = timestamp)
        elseif v isa TimeSeries.TimeArray
            continue
        else
            try
                data[k] =
                    TimeSeries.TimeArray(range(k, length = length(v), step = resolution))
            catch e
                throw(ArgumentError("The values in the data dict can't be converted to TimeArrays. Resulting error: $e"))
            end
        end
    end

    ta = handle_normalization_factor(ta, normalization_factor)
    return Deterministic(name, ta, scaling_factor_multiplier)
end

# TODO: need to make concatenation constructors for Probabilistic

function Deterministic(
    ts_metadata::DeterministicMetadata,
    data::SortedDict{Dates.DateTime, Array},
)
    return Deterministic(
        name = get_name(ts_metadata),
        initial_time_stamp = get_initial_time_stamp(ts_metadata),
        resolution = get_resolution(ts_metadata),
        horizon = get_horizon(ts_metadata),
        data = data,
        scaling_factor_multiplier = get_scaling_factor_multiplier(ts_metadata),
        internal = InfrastructureSystemsInternal(get_time_series_uuid(ts_metadata)),
    )
end

function DeterministicMetadata(ts::Deterministic)
    return DeterministicMetadata(
        get_name(ts),
        get_resolution(ts),
        get_initial_time_stamp(ts),
        get_interval(ts),
        get_count(ts),
        get_uuid(ts),
        get_horizon(ts),
        get_scaling_factor_multiplier(ts),
    )
end

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

function Scenarios(
    name::String,
    data::SortedDict{Dates.DateTime, TimeSeries.TimeArray},
    scaling_factor_multiplier = nothing,
)
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
        get_initial_time(time_series),
        get_interval(time_series),
        get_scenario_count(time_series),
        get_count(time_series),
        get_uuid(time_series),
        get_horizon(time_series),
        get_scaling_factor_multiplier(time_series),
    )
end

const _TS_DATA_TO_METADATA_MAP = Dict(
    Deterministic => DeterministicMetadata,
    Probabilistic => ProbabilisticMetadata,
    Scenarios => ScenariosMetadata,
    SingleTimeSeries => SingleTimeSeriesMetadata,
)

const _TS_METADATA_TO_DATA_MAP = Dict(
    DeterministicMetadata => Deterministic,
    ProbabilisticMetadata => Probabilistic,
    ScenariosMetadata => Scenarios,
    SingleTimeSeriesMetadata => SingleTimeSeries,
)

function time_series_data_to_metadata(::Type{T}) where {T <: TimeSeriesData}
    return _TS_DATA_TO_METADATA_MAP[T]
end

function time_series_metadata_to_data(::Type{T}) where {T <: TimeSeriesMetadata}
    return _TS_METADATA_TO_DATA_MAP[T]
end
