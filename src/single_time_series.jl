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
- `component::InfrastructureSystemsComponent`: component associated with the data
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
    ta = read_time_series(SingleTimeSeries, filename, component_name)
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
        get_initial_timestamp(ts),
        get_uuid(ts),
        length(ts),
        get_scaling_factor_multiplier(ts),
    )
end

function SingleTimeSeries(info::TimeSeriesParsedInfo)
    data = make_time_array(info)
    ts = handle_normalization_factor(data, info.normalization_factor)
    return SingleTimeSeries(
        name = info.name,
        data = ts,
        scaling_factor_multiplier = info.scaling_factor_multiplier,
    )
end

eltype_data(ts::SingleTimeSeries) = eltype(TimeSeries.values(ts.data))

get_initial_timestamp(time_series::SingleTimeSeries) =
    TimeSeries.timestamp(get_data(time_series))[1]

function get_resolution(time_series::SingleTimeSeries)
    data = get_data(time_series)
    return TimeSeries.timestamp(data)[2] - TimeSeries.timestamp(data)[1]
end

function get_array_for_hdf(ts::SingleTimeSeries)
    return transform_array_for_hdf(TimeSeries.values(ts.data))
end

function Base.getindex(time_series::SingleTimeSeries, args...)
    return SingleTimeSeries(time_series, getindex(get_data(time_series), args...))
end

Base.first(time_series::SingleTimeSeries) = head(time_series, 1)

Base.last(time_series::SingleTimeSeries) = tail(time_series, 1)

Base.firstindex(time_series::SingleTimeSeries) = firstindex(get_data(time_series))

Base.lastindex(time_series::SingleTimeSeries) = lastindex(get_data(time_series))

Base.lastindex(time_series::SingleTimeSeries, d) = lastindex(get_data(time_series), d)

Base.eachindex(time_series::SingleTimeSeries) = eachindex(get_data(time_series))

Base.iterate(time_series::SingleTimeSeries, n = 1) = iterate(get_data(time_series), n)

"""
Refer to TimeSeries.when(). Underlying data is copied.
"""
function when(time_series::SingleTimeSeries, period::Function, t::Integer)
    new = SingleTimeSeries(time_series, TimeSeries.when(get_data(time_series), period, t))
end

"""
Return a time_series truncated starting with timestamp.
"""
function from(time_series::SingleTimeSeries, timestamp)
    return SingleTimeSeries(
        name = get_name(time_series),
        data = TimeSeries.from(get_data(time_series), timestamp),
    )
end

"""
Return a time_series truncated after timestamp.
"""
function to(time_series::SingleTimeSeries, timestamp)
    return SingleTimeSeries(
        name = get_name(time_series),
        data = TimeSeries.to(get_data(time_series), timestamp),
    )
end

"""
Return a time_series with only the first num values.
"""
function head(time_series::SingleTimeSeries)
    return SingleTimeSeries(time_series, TimeSeries.head(get_data(time_series)))
end

function head(time_series::SingleTimeSeries, num)
    return SingleTimeSeries(time_series, TimeSeries.head(get_data(time_series), num))
end

"""
Return a time_series with only the ending num values.
"""
function tail(time_series::SingleTimeSeries)
    return SingleTimeSeries(time_series, TimeSeries.tail(get_data(time_series)))
end

function tail(time_series::SingleTimeSeries, num)
    return SingleTimeSeries(time_series, TimeSeries.tail(get_data(time_series), num))
end

"""
Creates a new SingleTimeSeries from an existing instance and a subset of data.
"""
function SingleTimeSeries(time_series::SingleTimeSeries, data::TimeSeries.TimeArray)
    vals = []
    for (fname, ftype) in zip(fieldnames(SingleTimeSeries), fieldtypes(SingleTimeSeries))
        if ftype <: TimeSeries.TimeArray
            val = data
        elseif ftype <: InfrastructureSystemsInternal
            # Need to create a new UUID.
            val = InfrastructureSystemsInternal()
        else
            val = getfield(time_series, fname)
        end

        push!(vals, val)
    end

    return SingleTimeSeries(vals...)
end

get_columns(::Type{<:TimeSeriesMetadata}, ta::TimeSeries.TimeArray) = nothing

function make_time_array(
    time_series::SingleTimeSeries,
    start_time::Dates.DateTime;
    len::Union{Nothing, Int} = nothing,
)
    ta = get_data(time_series)
    first_time = first(TimeSeries.timestamp(ta))
    if start_time == first_time && (len === nothing || len == length(ta))
        return ta
    end

    resolution = Dates.Millisecond(get_resolution(ta))
    start_index = Int((start_time - first_time) / resolution) + 1
    end_index = start_index + len - 1
    return ta[start_index:end_index]
end

function SingleTimeSeriesMetadata(ts_metadata::DeterministicMetadata)
    return SingleTimeSeriesMetadata(
        name = get_name(ts_metadata),
        resolution = get_resolution(ts_metadata),
        initial_timestamp = get_initial_timestamp(ts_metadata),
        time_series_uuid = get_time_series_uuid(ts_metadata),
        length = get_count(ts_metadata) * get_horizon(ts_metadata),
        scaling_factor_multiplier = get_scaling_factor_multiplier(ts_metadata),
        internal = get_internal(ts_metadata),
    )
end
