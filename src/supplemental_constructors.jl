"""
Construct Deterministic from a TimeArray or DataFrame.

# Arguments
- `label::AbstractString`: user-defined label
- `data::Union{TimeSeries.TimeArray, DataFrames.DataFrame}`: time series data
- `normalization_factor::NormalizationFactor = 1.0`: optional normalization factor to apply
  to each data entry
- `scaling_factor_multiplier::Union{Nothing, Function} = nothing`: If the data are scaling
  factors then this function will be called on the component and applied to the data when
  [`get_time_series_array`](@ref) is called.
- `timestamp = :timestamp`: If a DataFrame is passed then this must be the column name that
  contains timestamps.
"""
function Deterministic(
    label::AbstractString,
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
    return Deterministic(label, ta, scaling_factor_multiplier)
end

"""
Construct Deterministic from a CSV file. The file must have a column that is the name of the
component.

# Arguments
- `label::AbstractString`: user-defined label
- `filename::AbstractString`: name of CSV file containing data
- `normalization_factor::NormalizationFactor = 1.0`: optional normalization factor to apply
  to each data entry
- `scaling_factor_multiplier::Union{Nothing, Function} = nothing`: If the data are scaling
  factors then this function will be called on the component and applied to the data when
  [`get_time_series_array`](@ref) is called.
"""
function Deterministic(
    label::AbstractString,
    filename::AbstractString,
    component::InfrastructureSystemsComponent;
    normalization_factor::NormalizationFactor = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
)
    component_name = get_name(component)
    ta = read_time_series(filename, component_name)
    ta = handle_normalization_factor(ta[Symbol(component_name)], normalization_factor)
    return Deterministic(label, ta, scaling_factor_multiplier)
end

"""
Construct Deterministic after constructing a TimeArray from `initial_time` and
`time_steps`.
"""
function Deterministic(
    label::String,
    resolution::Dates.Period,
    initial_time::Dates.DateTime,
    time_steps::Int,
)
    data = TimeSeries.TimeArray(
        initial_time:resolution:(initial_time + resolution * (time_steps - 1)),
        ones(time_steps),
    )
    return Deterministic(; label = label, data = data)
end

function Deterministic(time_series::Vector{Deterministic})
    @assert !isempty(time_series)
    timestamps =
        collect(Iterators.flatten((TimeSeries.timestamp(get_data(x)) for x in time_series)))
    data = collect(Iterators.flatten((TimeSeries.values(get_data(x)) for x in time_series)))
    ta = TimeSeries.TimeArray(timestamps, data)

    time_series = Deterministic(
        label = get_label(time_series[1]),
        data = ta,
        scaling_factor_multiplier = time_series[1].scaling_factor_multiplier,
    )
    @debug "concatenated time_series" time_series
    return time_series
end

# TODO: need to make concatenation constructors for Probabilistic

function make_time_series_data(
    ts_metadata::DeterministicMetadata,
    data::TimeSeries.TimeArray,
)
    return Deterministic(
        get_label(ts_metadata),
        data,
        get_scaling_factor_multiplier(ts_metadata),
    )
end

function make_time_series_metadata(time_series::Deterministic, ta::TimeArrayWrapper)
    return DeterministicMetadata(
        get_label(time_series),
        ta,
        get_scaling_factor_multiplier(time_series),
    )
end

function DeterministicMetadata(
    label::AbstractString,
    data::TimeArrayWrapper,
    scaling_factor_multiplier = nothing,
)
    return DeterministicMetadata(
        label,
        get_resolution(data),
        get_initial_time(data),
        get_uuid(data),
        get_horizon(data),
        scaling_factor_multiplier,
    )
end

"""
Constructs Probabilistic after constructing a TimeArray from initial_time and time_steps.
"""
function Probabilistic(
    label::String,
    resolution::Dates.Period,
    initial_time::Dates.DateTime,
    percentiles::Vector{Float64},
    time_steps::Int,
)
    data = TimeSeries.TimeArray(
        initial_time:resolution:(initial_time + resolution * (time_steps - 1)),
        ones(time_steps, length(percentiles)),
    )

    return Probabilistic(; label = label, percentiles = percentiles, data = data)
end

"""
Constructs Probabilistic TimeSeriesData after constructing a TimeArray from initial_time and time_steps.
"""
# TODO: do we need this check still?
#function Probabilistic(
#                       label::String,
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
#    return Probabilistic(label, percentiles, data)
#end

function Probabilistic(
    label::String,
    resolution::Dates.Period,
    initial_time::Dates.DateTime,
    percentiles::Vector{Float64},  # percentiles for the probabilistic time_series
    data::TimeSeries.TimeArray,
)
    return Probabilistic(label = label, percentiles = percentiles, data = data)
end

function make_time_series_data(
    ts_metadata::ProbabilisticMetadata,
    data::TimeSeries.TimeArray,
)
    return Probabilistic(get_label(time_series), get_percentiles(time_series), data)
end

function make_time_series_metadata(time_series::Probabilistic, ta::TimeArrayWrapper)
    return ProbabilisticMetadata(
        get_label(time_series),
        get_resolution(time_series),
        get_initial_time(time_series),
        get_percentiles(time_series),
        get_uuid(ta),
        get_horizon(time_series),
        get_scaling_factor_multiplier(time_series),
    )
end

function Scenarios(
    label::String,
    data::TimeSeries.TimeArray,
    scaling_factor_multiplier = nothing,
)
    initial_time = TimeSeries.timestamp(data)[1]
    resolution = get_resolution(data)
    scenario_count = length(TimeSeries.colnames(data))
    return Scenarios(
        label = label,
        scenario_count = scenario_count,
        data = data,
        scaling_factor_multiplier = scaling_factor_multiplier,
    )
end

"""
Constructs Scenarios TimeSeriesData after constructing a TimeArray from initial_time and
time_steps.
"""
function Scenarios(
    label::String,
    resolution::Dates.Period,
    initial_time::Dates.DateTime,
    scenario_count::Int,
    time_steps::Int,
)
    data = TimeSeries.TimeArray(
        initial_time:resolution:(initial_time + resolution * (time_steps - 1)),
        ones(time_steps, scenario_count),
    )

    return Scenarios(label, data)
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
        Scenarios(get_label(time_series[1]), ta, time_series[1].scaling_factor_multiplier)
    @debug "concatenated time_series" time_series
    return time_series
end

function make_time_series_data(ts_metadata::ScenariosMetadata, data::TimeSeries.TimeArray)
    return Scenarios(get_label(ts_metadata), data)
end

function make_time_series_metadata(time_series::Scenarios, ta::TimeArrayWrapper)
    return ScenariosMetadata(
        get_label(time_series),
        get_resolution(time_series),
        get_initial_time(time_series),
        get_scenario_count(time_series),
        get_uuid(ta),
        get_horizon(time_series),
        get_scaling_factor_multiplier(time_series),
    )
end

function time_series_data_to_metadata(::Type{T}) where {T <: TimeSeriesData}
    if T <: Deterministic
        time_series_type = DeterministicMetadata
    elseif T <: Probabilistic
        time_series_type = ProbabilisticMetadata
    elseif T <: Scenarios
        time_series_type = ScenariosMetadata
    else
        @assert false
    end

    return time_series_type
end

function time_series_metadata_to_data(::Type{T}) where {T <: TimeSeriesMetadata}
    if T <: DeterministicMetadata
        time_series_type = Deterministic
    elseif T <: ProbabilisticMetadata
        time_series_type = Probabilistic
    elseif T <: ScenariosMetadata
        time_series_type = Scenarios
    else
        @assert false
    end

    return time_series_type
end
