"""
Stores all time series data in memory.
"""
struct InMemoryTimeSeriesStorage <: TimeSeriesStorage
    data::Dict{UUIDs.UUID, <:TimeSeriesData}
end

function InMemoryTimeSeriesStorage()
    storage = InMemoryTimeSeriesStorage(Dict{UUIDs.UUID, TimeSeriesData}())
    @debug "Created InMemoryTimeSeriesStorage" _group = LOG_GROUP_TIME_SERIES
    return storage
end

"""
Constructs InMemoryTimeSeriesStorage from an instance of Hdf5TimeSeriesStorage.
"""
function InMemoryTimeSeriesStorage(hdf5_storage::Hdf5TimeSeriesStorage)
    storage = InMemoryTimeSeriesStorage()
    for (_, time_series) in iterate_time_series(hdf5_storage)
        serialize_time_series!(storage, time_series)
    end

    return storage
end

function open_store!(
    func::Function,
    store::InMemoryTimeSeriesStorage,
    mode = "r",
    args...;
    kwargs...,
)
    func(args...; kwargs...)
end

Base.isempty(storage::InMemoryTimeSeriesStorage) = isempty(storage.data)

get_compression_settings(::InMemoryTimeSeriesStorage) =
    CompressionSettings(; enabled = false)

function serialize_time_series!(
    storage::InMemoryTimeSeriesStorage,
    ts::TimeSeriesData,
)
    uuid = get_uuid(ts)
    if haskey(storage.data, uuid)
        throw(ArgumentError("Time series UUID = $uuid is already stored"))
    end

    storage.data[uuid] = ts
    @debug "Create new time series entry." _group = LOG_GROUP_TIME_SERIES uuid
    return
end

function remove_time_series!(
    storage::InMemoryTimeSeriesStorage,
    uuid::UUIDs.UUID,
)
    if !haskey(storage.data, uuid)
        throw(ArgumentError("$uuid is not stored"))
    end

    pop!(storage.data, uuid)
end

function deserialize_time_series(
    ::Type{T},
    storage::InMemoryTimeSeriesStorage,
    ts_metadata::TimeSeriesMetadata,
    rows::UnitRange,
    columns::UnitRange,
) where {T <: StaticTimeSeries}
    uuid = get_time_series_uuid(ts_metadata)
    if !haskey(storage.data, uuid)
        throw(ArgumentError("$uuid is not stored"))
    end

    ts_data = get_data(storage.data[uuid])
    total_rows = length(ts_metadata)
    if rows.start == 1 && length(rows) == total_rows
        # No memory allocation
        return T(ts_metadata, ts_data)
    end

    # TimeArray doesn't support @view
    return T(ts_metadata, ts_data[rows])
end

function deserialize_time_series(
    ::Type{T},
    storage::InMemoryTimeSeriesStorage,
    ts_metadata::TimeSeriesMetadata,
    rows::UnitRange,
    columns::UnitRange,
) where {T <: TimeSeriesData}
    uuid = get_time_series_uuid(ts_metadata)
    if !haskey(storage.data, uuid)
        throw(ArgumentError("$uuid is not stored"))
    end

    ts = storage.data[uuid]
    ts_data = get_data(ts)
    if ts isa SingleTimeSeries
        return deserialize_deterministic_from_single_time_series(
            storage,
            ts_metadata,
            rows,
            columns,
            length(ts_data),
        )
    end

    total_rows = length(ts_metadata)
    total_columns = get_count(ts_metadata)
    if length(rows) == total_rows && length(columns) == total_columns
        return T(ts_metadata, ts_data)
    end

    initial_timestamp = get_initial_timestamp(ts_metadata)
    resolution = get_resolution(ts_metadata)
    interval = get_interval(ts_metadata)
    start_time = initial_timestamp + interval * (columns.start - 1)
    data = SortedDict{Dates.DateTime, eltype(typeof(ts_data)).parameters[2]}()
    for initial_time in range(start_time; step = interval, length = length(columns))
        if rows.start == 1
            it = initial_time
        else
            it = initial_time + (rows.start - 1) * resolution
        end
        data[it] = @view ts_data[initial_time][rows]
    end

    if T <: AbstractDeterministic
        return Deterministic(ts_metadata, data)
    else
        return T(ts_metadata, data)
    end
end

function clear_time_series!(storage::InMemoryTimeSeriesStorage)
    empty!(storage.data)
    @info "Cleared all time series."
end

function get_num_time_series(storage::InMemoryTimeSeriesStorage)
    return length(storage.data)
end

function convert_to_hdf5(storage::InMemoryTimeSeriesStorage, filename::AbstractString)
    create_file = true
    hdf5_storage = Hdf5TimeSeriesStorage(create_file; filename = filename)
    for ts in values(storage.data)
        serialize_time_series!(hdf5_storage, ts)
    end
end

function compare_values(
    x::InMemoryTimeSeriesStorage,
    y::InMemoryTimeSeriesStorage;
    compare_uuids = false,
    kwargs...,
)
    keys_x = sort!(collect(keys(x.data)))
    keys_y = sort!(collect(keys(y.data)))
    if keys_x != keys_y
        @error "keys don't match" keys_x keys_y
        return false
    end

    for key in keys_x
        ts_x = x.data[key]
        ts_y = y.data[key]
        if TimeSeries.timestamp(get_data(ts_x)) != TimeSeries.timestamp(get_data(ts_y))
            @error "timestamps don't match" ts_x ts_y
            return false
        end
        if TimeSeries.values(get_data(ts_x)) != TimeSeries.values(get_data(ts_y))
            @error "values don't match" ts_x ts_y
            return false
        end
    end

    return true
end
