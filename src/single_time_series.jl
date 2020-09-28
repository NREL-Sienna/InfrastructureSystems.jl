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

get_initial_time(time_series::SingleTimeSeries) =
    TimeSeries.timestamp(get_data(time_series))[1]

function get_resolution(time_series::SingleTimeSeries)
    data = get_data(time_series)
    return TimeSeries.timestamp(data)[2] - TimeSeries.timestamp(data)[1]
end

function get_array_for_hdf(ts::SingleTimeSeries)
    return TimeSeries.values(ts.data)
end

function Base.getindex(time_series::SingleTimeSeries, args...)
    return split_time_series(time_series, getindex(get_data(time_series), args...))
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
    new = split_time_series(time_series, TimeSeries.when(get_data(time_series), period, t))

end

"""
Return a time_series truncated starting with timestamp.
"""
function from(time_series::T, timestamp) where {T <: SingleTimeSeries}
    return T(;
        name = get_name(time_series),
        data = TimeSeries.from(get_data(time_series), timestamp),
    )
end

"""
Return a time_series truncated after timestamp.
"""
function to(time_series::T, timestamp) where {T <: SingleTimeSeries}
    return T(;
        name = get_name(time_series),
        data = TimeSeries.to(get_data(time_series), timestamp),
    )
end

"""
Return a time_series with only the first num values.
"""
function head(time_series::SingleTimeSeries)
    return split_time_series(time_series, TimeSeries.head(get_data(time_series)))
end

function head(time_series::SingleTimeSeries, num)
    return split_time_series(time_series, TimeSeries.head(get_data(time_series), num))
end

"""
Return a time_series with only the ending num values.
"""
function tail(time_series::SingleTimeSeries)
    return split_time_series(time_series, TimeSeries.tail(get_data(time_series)))
end

function tail(time_series::SingleTimeSeries, num)
    return split_time_series(time_series, TimeSeries.tail(get_data(time_series), num))
end

"""
Creates a new SingleTimeSeries from an existing instance and a subset of data.
"""
function split_time_series(
    time_series::T,
    data::TimeSeries.TimeArray,
) where {T <: SingleTimeSeries}
    vals = []
    for (fname, ftype) in zip(fieldnames(T), fieldtypes(T))
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

    return T(vals...)
end

get_columns(::Type{<:TimeSeriesMetadata}, ta::TimeSeries.TimeArray) = nothing

function SingleTimeSeries(info::TimeSeriesParsedInfo)
    data = make_time_array(info)
    ts = handle_normalization_factor(data, info.normalization_factor)
    return SingleTimeSeries(
        name = info.name,
        data = ts,
        scaling_factor_multiplier = info.scaling_factor_multiplier,
    )
end
