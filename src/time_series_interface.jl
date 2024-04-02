"""
Return the TimeSeriesManager or nothing if the component/attribute does not support time
series.
"""
function get_time_series_manager(owner::TimeSeriesOwners)
    container = get_time_series_container(owner)
    isnothing(container) && return nothing
    return get_time_series_manager(container)
end

function set_time_series_manager!(
    owner::TimeSeriesOwners,
    time_series_manager::Union{Nothing, TimeSeriesManager},
)
    container = get_time_series_container(owner)
    if !isnothing(container)
        set_time_series_manager!(container, time_series_manager)
    end
    return
end

function get_time_series_storage(owner::TimeSeriesOwners)
    mgr = get_time_series_manager(owner)
    if isnothing(mgr)
        return nothing
    end

    return mgr.data_store
end

"""
Return a time series corresponding to the given parameters.

# Arguments

  - `::Type{T}`: Concrete subtype of TimeSeriesData to return
  - `owner::TimeSeriesOwners`: Component or attribute containing the time series
  - `name::AbstractString`: name of time series
  - `start_time::Union{Nothing, Dates.DateTime} = nothing`: If nothing, use the
    `initial_timestamp` of the time series. If T is a subtype of Forecast then `start_time`
    must be the first timstamp of a window.
  - `len::Union{Nothing, Int} = nothing`: Length in the time dimension. If nothing, use the
    entire length.
  - `count::Union{Nothing, Int} = nothing`: Only applicable to subtypes of Forecast. Number
    of forecast windows starting at `start_time` to return. Defaults to all available.
"""
function get_time_series(
    ::Type{T},
    owner::TimeSeriesOwners,
    name::AbstractString;
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Nothing, Int} = nothing,
    count::Union{Nothing, Int} = nothing,
    features...,
) where {T <: TimeSeriesData}
    ts_metadata = get_time_series_metadata(T, owner, name; features...)
    start_time = _check_start_time(start_time, ts_metadata)
    rows = _get_rows(start_time, len, ts_metadata)
    columns = _get_columns(start_time, count, ts_metadata)
    storage = get_time_series_storage(owner)
    return deserialize_time_series(T, storage, ts_metadata, rows, columns)
end

function get_time_series_uuid(
    ::Type{T},
    owner::TimeSeriesOwners,
    name::AbstractString,
) where {T <: TimeSeriesData}
    metadata_type = time_series_data_to_metadata(T)
    metadata = get_time_series_metadata(metadata_type, owner, name)
    return get_time_series_uuid(metadata)
end

function get_time_series_metadata(
    ::Type{T},
    owner::TimeSeriesOwners,
    name::AbstractString;
    features...,
) where {T <: TimeSeriesData}
    mgr = get_time_series_manager(owner)
    return get_metadata(mgr, owner, T, name; features...)
end

"""
Return a TimeSeries.TimeArray from storage for the given time series parameters.

If the data are scaling factors then the stored scaling_factor_multiplier will be called on
the owner and applied to the data unless ignore_scaling_factors is true.
"""
function get_time_series_array(
    ::Type{T},
    owner::TimeSeriesOwners,
    name::AbstractString;
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Nothing, Int} = nothing,
    ignore_scaling_factors = false,
) where {T <: TimeSeriesData}
    ts = get_time_series(T, owner, name; start_time = start_time, len = len, count = 1)
    if start_time === nothing
        start_time = get_initial_timestamp(ts)
    end

    return get_time_series_array(
        owner,
        ts,
        start_time;
        len = len,
        ignore_scaling_factors = ignore_scaling_factors,
    )
end

"""
Return a TimeSeries.TimeArray for one forecast window from a cached Forecast instance.

If the data are scaling factors then the stored scaling_factor_multiplier will be called on
the owner and applied to the data unless ignore_scaling_factors is true.

See also [`ForecastCache`](@ref).
"""
function get_time_series_array(
    owner::TimeSeriesOwners,
    forecast::Forecast,
    start_time::Dates.DateTime;
    len = nothing,
    ignore_scaling_factors = false,
)
    return _make_time_array(owner, forecast, start_time, len, ignore_scaling_factors)
end

"""
Return a TimeSeries.TimeArray from a cached StaticTimeSeries instance.

If the data are scaling factors then the stored scaling_factor_multiplier will be called on
the owner and applied to the data unless ignore_scaling_factors is true.

See also [`StaticTimeSeriesCache`](@ref).
"""
function get_time_series_array(
    owner::TimeSeriesOwners,
    time_series::StaticTimeSeries,
    start_time::Union{Nothing, Dates.DateTime} = nothing;
    len::Union{Nothing, Int} = nothing,
    ignore_scaling_factors = false,
)
    if start_time === nothing
        start_time = get_initial_timestamp(time_series)
    end

    if len === nothing
        len = length(time_series)
    end

    return _make_time_array(owner, time_series, start_time, len, ignore_scaling_factors)
end

"""
Return a vector of timestamps from storage for the given time series parameters.
"""
function get_time_series_timestamps(
    ::Type{T},
    owner::TimeSeriesOwners,
    name::AbstractString;
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Nothing, Int} = nothing,
) where {T <: TimeSeriesData}
    return TimeSeries.timestamp(
        get_time_series_array(T, owner, name; start_time = start_time, len = len),
    )
end

"""
Return a vector of timestamps from a cached Forecast instance.
"""
function get_time_series_timestamps(
    owner::TimeSeriesOwners,
    forecast::Forecast,
    start_time::Union{Nothing, Dates.DateTime} = nothing;
    len::Union{Nothing, Int} = nothing,
)
    return TimeSeries.timestamp(
        get_time_series_array(owner, forecast, start_time; len = len),
    )
end

"""
Return a vector of timestamps from a cached StaticTimeSeries instance.
"""
function get_time_series_timestamps(
    owner::TimeSeriesOwners,
    time_series::StaticTimeSeries,
    start_time::Union{Nothing, Dates.DateTime} = nothing;
    len::Union{Nothing, Int} = nothing,
)
    return TimeSeries.timestamp(
        get_time_series_array(owner, time_series, start_time; len = len),
    )
end

"""
Return an Array of values from storage for the requested time series parameters.

If the data size is small and this will be called many times, consider using the version
that accepts a cached TimeSeriesData instance.
"""
function get_time_series_values(
    ::Type{T},
    owner::TimeSeriesOwners,
    name::AbstractString;
    start_time::Union{Nothing, Dates.DateTime} = nothing,
    len::Union{Nothing, Int} = nothing,
    ignore_scaling_factors = false,
) where {T <: TimeSeriesData}
    return TimeSeries.values(
        get_time_series_array(
            T,
            owner,
            name;
            start_time = start_time,
            len = len,
            ignore_scaling_factors = ignore_scaling_factors,
        ),
    )
end

"""
Return an Array of values for one forecast window from a cached Forecast instance.
"""
function get_time_series_values(
    owner::TimeSeriesOwners,
    forecast::Forecast,
    start_time::Dates.DateTime;
    len::Union{Nothing, Int} = nothing,
    ignore_scaling_factors = false,
)
    return TimeSeries.values(
        get_time_series_array(
            owner,
            forecast,
            start_time;
            len = len,
            ignore_scaling_factors = ignore_scaling_factors,
        ),
    )
end

"""
Return an Array of values from a cached StaticTimeSeries instance for the requested time
series parameters.
"""
function get_time_series_values(
    owner::TimeSeriesOwners,
    time_series::StaticTimeSeries,
    start_time::Union{Nothing, Dates.DateTime} = nothing;
    len::Union{Nothing, Int} = nothing,
    ignore_scaling_factors = false,
)
    return TimeSeries.values(
        get_time_series_array(
            owner,
            time_series,
            start_time;
            len = len,
            ignore_scaling_factors = ignore_scaling_factors,
        ),
    )
end

function _make_time_array(owner, time_series, start_time, len, ignore_scaling_factors)
    ta = make_time_array(time_series, start_time; len = len)
    if ignore_scaling_factors
        return ta
    end

    multiplier = get_scaling_factor_multiplier(time_series)
    if multiplier === nothing
        return ta
    end

    return ta .* multiplier(owner)
end

"""
Return true if the component or supplemental attribute has time series data.
"""
function has_time_series(owner::TimeSeriesOwners)
    return has_time_series(get_time_series_manager(owner), owner)
end

"""
Return true if the component or supplemental attribute has time series data of type T.
"""
function has_time_series(
    val::TimeSeriesOwners,
    ::Type{T},
) where {T <: TimeSeriesData}
    mgr = get_time_series_manager(val)
    isnothing(mgr) && return false
    return has_time_series(mgr.metadata_store, val, T)
end

"""
Return true if the component or supplemental attribute supports time series data.
"""
function supports_time_series(owner::TimeSeriesOwners)
    return !isnothing(get_time_series_container(owner))
end

function throw_if_does_not_support_time_series(owner::TimeSeriesOwners)
    if !supports_time_series(owner)
        throw(ArgumentError("$(summary(owner)) does not support time series"))
    end
end

"""
Efficiently add all time_series in one component to another by copying the underlying
references.

# Arguments

  - `dst::TimeSeriesOwners`: Destination owner
  - `src::TimeSeriesOwners`: Source owner
  - `name_mapping::Dict = nothing`: Optionally map src names to different dst names.
    If provided and src has a time_series with a name not present in name_mapping, that
    time_series will not copied. If name_mapping is nothing then all time_series will be
    copied with src's names.
  - `scaling_factor_multiplier_mapping::Dict = nothing`: Optionally map src multipliers to
    different dst multipliers.  If provided and src has a time_series with a multiplier not
    present in scaling_factor_multiplier_mapping, that time_series will not copied. If
    scaling_factor_multiplier_mapping is nothing then all time_series will be copied with
    src's multipliers.
"""
function copy_time_series!(
    dst::TimeSeriesOwners,
    src::TimeSeriesOwners;
    name_mapping::Union{Nothing, Dict{Tuple{String, String}, String}} = nothing,
    scaling_factor_multiplier_mapping::Union{Nothing, Dict{String, String}} = nothing,
)
    storage = get_time_series_storage(dst)
    if isnothing(storage)
        throw(
            ArgumentError(
                "$(summary(dst)) does not have time series storage. " *
                "It may not be attached to the system.",
            ),
        )
    end

    mgr = get_time_series_manager(dst)
    @assert !isnothing(mgr)

    for ts_metadata in list_time_series_metadata(src)
        name = get_name(ts_metadata)
        new_name = name
        if !isnothing(name_mapping)
            new_name = get(name_mapping, (get_name(src), name), nothing)
            if isnothing(new_name)
                @debug "Skip copying ts_metadata" _group = LOG_GROUP_TIME_SERIES name
                continue
            end
            @debug "Copy ts_metadata with" _group = LOG_GROUP_TIME_SERIES new_name
        end
        multiplier = get_scaling_factor_multiplier(ts_metadata)
        new_multiplier = multiplier
        if !isnothing(scaling_factor_multiplier_mapping)
            new_multiplier = get(scaling_factor_multiplier_mapping, multiplier, nothing)
            if isnothing(new_multiplier)
                @debug "Skip copying ts_metadata" _group = LOG_GROUP_TIME_SERIES multiplier
                continue
            end
            @debug "Copy ts_metadata with" _group = LOG_GROUP_TIME_SERIES new_multiplier
        end
        new_time_series = deepcopy(ts_metadata)
        assign_new_uuid_internal!(new_time_series)
        set_name!(new_time_series, new_name)
        set_scaling_factor_multiplier!(new_time_series, new_multiplier)
        add_metadata!(mgr.metadata_store, dst, new_time_series)
    end
end

function list_time_series_info(owner::TimeSeriesOwners)
    mgr = get_time_series_manager(owner)
    isnothing(mgr) && return []
    return list_time_series_info(mgr.metadata_store, owner)
end

function list_time_series_metadata(
    owner::TimeSeriesOwners;
    time_series_type::Union{Type{<:TimeSeriesData}, Nothing} = nothing,
    name::Union{String, Nothing} = nothing,
    features...,
)
    mgr = get_time_series_manager(owner)
    isnothing(mgr) && return []
    return list_metadata(
        mgr,
        owner;
        time_series_type = time_series_type,
        name = name,
        features...,
    )
end

function get_num_time_series(owner::TimeSeriesOwners)
    mgr = get_time_series_manager(owner)
    if isnothing(mgr)
        return (0, 0)
    end

    static_ts_count = 0
    forecast_count = 0
    for metadata in list_metadata(mgr.metadata_store, owner)
        if metadata isa StaticTimeSeriesMetadata
            static_ts_count += 1
        elseif metadata isa ForecastMetadata
            forecast_count += 1
        else
            error("panic")
        end
    end

    return (static_ts_count, forecast_count)
end

function get_num_time_series_by_type(owner::TimeSeriesOwners)
    counts = Dict{String, Int}()
    mgr = get_time_series_manager(owner)
    if isnothing(mgr)
        return counts
    end

    for metadata in list_metadata(mgr.metadata_store, owner)
        type = string(nameof(time_series_metadata_to_data(metadata)))
        if haskey(counts, type)
            counts[type] += 1
        else
            counts[type] = 1
        end
    end

    return counts
end

function get_time_series(
    owner::TimeSeriesOwners,
    time_series::TimeSeriesData,
)
    storage = get_time_series_storage(owner)
    return get_time_series(storage, get_time_series_uuid(time_series))
end

function get_time_series_uuids(owner::TimeSeriesOwners)
    mgr = get_time_series_manager(owner)
    if isnothing(mgr)
        return []
    end

    return [
        (get_time_series_uuid(x), get_name(x)) for
        x in list_metadata(mgr.metadata_store, owner)
    ]
end

function clear_time_series!(owner::TimeSeriesOwners)
    mgr = get_time_series_manager(owner)
    if !isnothing(mgr)
        clear_time_series!(mgr, owner)
    end
    return
end

"""
Return a time series from TimeSeriesFileMetadata.

# Arguments

  - `cache::TimeSeriesParsingCache`: cached data
  - `ts_file_metadata::TimeSeriesFileMetadata`: metadata
  - `resolution::{Nothing, Dates.Period}`: skip any time_series that don't match this resolution
"""
function make_time_series!(
    cache::TimeSeriesParsingCache,
    ts_file_metadata::TimeSeriesFileMetadata,
)
    info = add_time_series_info!(cache, ts_file_metadata)
    return ts_file_metadata.time_series_type(info)
end

function add_time_series_info!(
    cache::TimeSeriesParsingCache,
    metadata::TimeSeriesFileMetadata,
)
    time_series = _add_time_series_info!(cache, metadata)
    info = TimeSeriesParsedInfo(metadata, time_series)
    @debug "Added TimeSeriesParsedInfo" _group = LOG_GROUP_TIME_SERIES metadata
    return info
end

function _get_columns(start_time, count, ts_metadata::ForecastMetadata)
    offset = start_time - get_initial_timestamp(ts_metadata)
    interval = time_period_conversion(get_interval(ts_metadata))
    window_count = get_count(ts_metadata)
    if window_count > 1
        index = Int(offset / interval) + 1
    else
        index = 1
    end
    if count === nothing
        count = window_count - index + 1
    end

    if index + count - 1 > get_count(ts_metadata)
        throw(
            ArgumentError(
                "The requested start_time $start_time and count $count are invalid",
            ),
        )
    end
    return UnitRange(index, index + count - 1)
end

_get_columns(start_time, count, ts_metadata::StaticTimeSeriesMetadata) = UnitRange(1, 1)

function _get_rows(start_time, len, ts_metadata::StaticTimeSeriesMetadata)
    index =
        Int(
            (start_time - get_initial_timestamp(ts_metadata)) / get_resolution(ts_metadata),
        ) + 1
    if len === nothing
        len = length(ts_metadata) - index + 1
    end
    if index + len - 1 > length(ts_metadata)
        throw(
            ArgumentError(
                "The requested index=$index len=$len exceeds the range $(length(ts_metadata))",
            ),
        )
    end

    return UnitRange(index, index + len - 1)
end

function _get_rows(start_time, len, ts_metadata::ForecastMetadata)
    if len === nothing
        len = get_horizon(ts_metadata)
    end

    return UnitRange(1, len)
end

function _check_start_time(start_time, ts_metadata::TimeSeriesMetadata)
    if start_time === nothing
        return get_initial_timestamp(ts_metadata)
    end

    time_diff = start_time - get_initial_timestamp(ts_metadata)
    if time_diff < Dates.Second(0)
        throw(
            ArgumentError(
                "start_time=$start_time is earlier than $(get_initial_timestamp(ts_metadata))",
            ),
        )
    end

    if typeof(ts_metadata) <: ForecastMetadata
        window_count = get_count(ts_metadata)
        interval = get_interval(ts_metadata)
        if window_count > 1 &&
           Dates.Millisecond(time_diff) % Dates.Millisecond(interval) != Dates.Second(0)
            throw(
                ArgumentError(
                    "start_time=$start_time is not on a multiple of interval=$interval",
                ),
            )
        end
    end

    return start_time
end

function get_forecast_window_count(initial_timestamp, interval, resolution, len, horizon)
    if interval == Dates.Second(0)
        count = 1
    else
        last_timestamp = initial_timestamp + resolution * (len - 1)
        last_initial_time = last_timestamp - resolution * (horizon - 1)

        # Reduce last_initial_time to the nearest interval if necessary.
        diff =
            Dates.Millisecond(last_initial_time - initial_timestamp) %
            Dates.Millisecond(interval)
        if diff != Dates.Millisecond(0)
            last_initial_time -= diff
        end
        count =
            Dates.Millisecond(last_initial_time - initial_timestamp) /
            Dates.Millisecond(interval) + 1
    end

    return count
end
