abstract type TimeSeriesFileFormat end
abstract type TimeSeriesFormatPeriodAsColumn <: TimeSeriesFileFormat end
abstract type TimeSeriesFormatYMDPeriodAsColumn <: TimeSeriesFormatPeriodAsColumn end
abstract type TimeSeriesFormatDateTimePeriodAsColumn <: TimeSeriesFormatPeriodAsColumn end
abstract type TimeSeriesFormatPeriodAsHeader <: TimeSeriesFileFormat end
abstract type TimeSeriesFormatYMDPeriodAsHeader <: TimeSeriesFormatPeriodAsHeader end
abstract type TimeSeriesFormatComponentsAsColumnsNoTime <: TimeSeriesFileFormat end
abstract type TimeSeriesFormatDateTimeAsColumn <: TimeSeriesFileFormat end

"""
Return a TimeArray from a CSV file.

Pass component_name when the file does not have the component name in a column header.
"""
function read_time_series(
    ::Type{T},
    data_file::AbstractString,
    component_name=nothing;
    kwargs...,
) where {T <: TimeSeriesData}
    if !isfile(data_file)
        msg = "TimeSeries file doesn't exist : $(data_file)"
        throw(DataFormatError(msg))
    end

    file = CSV.File(data_file)
    @debug "Read CSV data from $(data_file)." _group = LOG_GROUP_TIME_SERIES

    format = get_time_series_format(file)
    @debug "$format detected for the time series" _group = LOG_GROUP_TIME_SERIES
    return read_time_series(format, T, file, component_name; kwargs...)
end

function read_time_series(metadata::TimeSeriesFileMetadata; kwargs...)
    return read_time_series(
        metadata.time_series_type,
        metadata.data_file,
        metadata.component_name;
        kwargs...,
    )
end

"""
Return the time series format used in the CSV file.
"""
function get_time_series_format(file::CSV.File)
    columns = propertynames(file)
    has_ymd = :Year in columns && :Month in columns && :Day in columns
    has_period = :Period in columns
    has_datetime = :DateTime in columns

    if has_period
        if has_datetime
            format = TimeSeriesFormatDateTimePeriodAsColumn
        else
            format = TimeSeriesFormatYMDPeriodAsColumn
        end
    elseif has_ymd
        format = TimeSeriesFormatYMDPeriodAsHeader
    elseif has_datetime
        format = TimeSeriesFormatDateTimeAsColumn
    else
        format = TimeSeriesFormatComponentsAsColumnsNoTime
    end

    if format in (TimeSeriesFormatYMDPeriodAsColumn, TimeSeriesFormatYMDPeriodAsHeader)
        if !has_ymd
            throw(DataFormatError("$(file.name) is missing required Year/Month/Day"))
        end
    end

    return format
end

"""
Return the column names with values (components).
"""
function get_value_columns(::Type{TimeSeriesFormatYMDPeriodAsColumn}, file::CSV.File)
    return [x for x in propertynames(file) if !in(x, (:Year, :Month, :Day, :Period))]
end

function get_value_columns(
    ::Type{T},
    file::CSV.File,
) where {
    T <: Union{TimeSeriesFormatDateTimePeriodAsColumn, TimeSeriesFormatDateTimeAsColumn},
}
    return [x for x in propertynames(file) if !in(x, (:DateTime, :Period))]
end

"""
Return the column names with values.
"""
function get_value_columns(
    ::Type{TimeSeriesFormatComponentsAsColumnsNoTime},
    file::CSV.File,
)
    return propertynames(file)
end

"""
Return the column names that specify the Period.
"""
function get_period_columns(::Type{TimeSeriesFormatPeriodAsColumn}, file::CSV.File)
    return [:Period]
end

function get_period_columns(::Type{TimeSeriesFormatYMDPeriodAsHeader}, file::CSV.File)
    return [x for x in propertynames(file) if !in(x, (:Year, :Month, :Day))]
end

"""
Return a vector of dicts of unique timestamps and their counts.
"""
function get_unique_timestamps(::Type{T}, file::CSV.File) where {T <: TimeSeriesFileFormat}
    timestamps = Vector{Dict{String, Any}}()
    new_timestamp = x -> Dict("timestamp" => x, "count" => 1)

    for i in 1:length(file)
        timestamp = get_timestamp(T, file, i)
        if i == 1
            push!(timestamps, new_timestamp(timestamp))
        else
            if timestamp == timestamps[end]["timestamp"]
                timestamps[end]["count"] += 1
            else
                push!(timestamps, new_timestamp(timestamp))
            end
        end
    end

    @assert_op length(timestamps) > 0
    for timestamp in timestamps[2:end]
        @assert_op timestamp["count"] == timestamps[1]["count"]
    end

    return timestamps
end

"""
Return a Dates.DateTime for the row in the CSV file.
"""
function get_timestamp(
    ::Type{TimeSeriesFormatYMDPeriodAsColumn},
    file::CSV.File,
    row_index::Int,
)
    return Dates.DateTime(file.Year[row_index], file.Month[row_index], file.Day[row_index])
end

function get_timestamp(
    ::Type{T},
    file::CSV.File,
    row_index::Int,
) where {
    T <: Union{TimeSeriesFormatDateTimePeriodAsColumn, TimeSeriesFormatDateTimeAsColumn},
}
    return Dates.DateTime(file.DateTime[row_index])
end

function get_timestamp(
    ::Type{TimeSeriesFormatYMDPeriodAsHeader},
    file::CSV.File,
    row_index::Int,
)
    return get_timestamp(TimeSeriesFormatYMDPeriodAsColumn, file, row_index)
end

"""
Return a RawTimeSeries from a CSV file.

Pass component_name when the file does not have the component name in a column header.
"""
function read_time_series(
    ::Type{T},
    ::Type{Deterministic},
    file::CSV.File,
    component_name=nothing;
    kwargs...,
) where {T <: TimeSeriesFormatDateTimeAsColumn}
    @debug "Read CSV data from $file." _group = LOG_GROUP_TIME_SERIES
    horizon = length(first(file)) - 1
    data = SortedDict{Dates.DateTime, Vector{Float64}}()
    # First element in the row is the time series. We use integer indexes not to rely on
    # column names
    for row in file
        vector = Vector{Float64}(undef, horizon)
        for i in 1:horizon
            vector[i] = row[i + 1]
        end
        data[Dates.DateTime(row.DateTime)] = vector
    end
    return RawTimeSeries(first(keys(data)), data, horizon)
end

"""
Return a TimeSeries.TimeArray representing the CSV file.

This version of the function only has component_name to match the interface. It is unused.
"""
function read_time_series(
    ::Type{T},
    ::Type{<:StaticTimeSeries},
    file::CSV.File,
    component_name=nothing;
    kwargs...,
) where {T <: Union{TimeSeriesFormatPeriodAsColumn, TimeSeriesFormatDateTimeAsColumn}}
    first_timestamp = get_timestamp(T, file, 1)
    value_columns = get_value_columns(T, file)
    vals = [(string(x) => getproperty(file, x)) for x in value_columns]
    series_length = length(vals[1][2])
    return RawTimeSeries(first_timestamp, Dict(vals...), series_length)
end

"""
This version of the function supports the format where there is no column header for
a component, so the component_name must be passed in.
"""
function read_time_series(
    ::Type{T},
    ::Type{<:StaticTimeSeries},
    file::CSV.File,
    component_name::AbstractString;
    kwargs...,
) where {T <: TimeSeriesFormatPeriodAsHeader}
    period_cols_as_symbols = get_period_columns(T, file)
    period = [parse(Int, string(x)) for x in period_cols_as_symbols]
    first_timestamp = get_timestamp(T, file, 1)
    vals = Vector{Float64}()
    for i in 1:length(file)
        for period in period_cols_as_symbols
            val = getproperty(file, period)[i]
            push!(vals, val)
        end
    end

    return RawTimeSeries(first_timestamp, Dict(component_name => vals), length(vals))
end

"""
This version of the function only has component_name to match the interface.
It is unused.

Set start_datetime as a keyword argument for the starting timestamp, otherwise the current
day is used.
"""
function read_time_series(
    ::Type{T},
    ::Type{<:StaticTimeSeries},
    file::CSV.File,
    component_name=nothing;
    kwargs...,
) where {T <: TimeSeriesFormatComponentsAsColumnsNoTime}
    first_timestamp = get(kwargs, :start_datetime, Dates.DateTime(Dates.today()))
    value_columns = get_value_columns(T, file)
    vals = [(string(x) => getproperty(file, x)) for x in value_columns]
    series_length = length(vals[1][2])
    return RawTimeSeries(first_timestamp, Dict(vals...), series_length)
end

"""
Return the number of steps specified by the period in the file.
"""
function get_num_steps(
    ::Type{T},
    file::CSV.File,
    period::AbstractArray,
) where {T <: TimeSeriesFileFormat}
    error("Unsupported time series file format")
end

"""
Return the number of steps specified by the period in the file.
"""
function get_num_steps(
    ::Type{T},
    file::CSV.File,
    period::AbstractArray,
) where {T <: Union{TimeSeriesFormatPeriodAsColumn, TimeSeriesFormatDateTimeAsColumn}}
    timestamps = get_unique_timestamps(T, file)
    return timestamps[1]["count"]
end

"""
Return the number of steps specified by the period in the file.
"""
function get_num_steps(
    ::Type{T},
    file::CSV.File,
    period::AbstractArray,
) where {T <: TimeSeriesFormatPeriodAsHeader}
    return num_steps = period[end]
end
