
const _ComponentnameReferences = Set{Tuple{UUIDs.UUID, String}}

struct _TimeSeriesRecord
    component_names::_ComponentnameReferences
    ts::TimeSeriesData
end

function _TimeSeriesRecord(component_uuid, name, ts)
    record = _TimeSeriesRecord(_ComponentnameReferences(), ts)
    push!(record.component_names, (component_uuid, name))
    return record
end

"""
Stores all time series data in memory.
"""
struct InMemoryTimeSeriesStorage <: TimeSeriesStorage
    data::Dict{UUIDs.UUID, _TimeSeriesRecord}
end

function InMemoryTimeSeriesStorage()
    storage = InMemoryTimeSeriesStorage(Dict{UUIDs.UUID, _TimeSeriesRecord}())
    @debug "Created InMemoryTimeSeriesStorage"
    return storage
end

"""
Constructs InMemoryTimeSeriesStorage from an instance of Hdf5TimeSeriesStorage.
"""
function InMemoryTimeSeriesStorage(hdf5_storage::Hdf5TimeSeriesStorage)
    storage = InMemoryTimeSeriesStorage()
    for (component, name, time_series) in iterate_time_series(hdf5_storage)
        serialize_time_series!(storage, component, name, time_series)
    end

    return storage
end

check_read_only(storage::InMemoryTimeSeriesStorage) = nothing

function serialize_time_series!(
    storage::InMemoryTimeSeriesStorage,
    component_uuid::UUIDs.UUID,
    name::AbstractString,
    ts::TimeSeriesData,
)
    uuid = get_uuid(ts)
    if !haskey(storage.data, uuid)
        @debug "Create new time series entry." uuid component_uuid name
        storage.data[uuid] = _TimeSeriesRecord(component_uuid, name, ts)
    else
        add_time_series_reference!(storage, component_uuid, name, uuid)
    end

    return
end

function add_time_series_reference!(
    storage::InMemoryTimeSeriesStorage,
    component_uuid::UUIDs.UUID,
    name::AbstractString,
    ts_uuid::UUIDs.UUID,
)
    @debug "Add reference to existing time series entry." ts_uuid component_uuid name
    record = storage.data[ts_uuid]
    push!(record.component_names, (component_uuid, name))
end

function remove_time_series!(
    storage::InMemoryTimeSeriesStorage,
    uuid::UUIDs.UUID,
    component_uuid::UUIDs.UUID,
    name::AbstractString,
)
    if !haskey(storage.data, uuid)
        throw(ArgumentError("$uuid is not stored"))
    end

    record = storage.data[uuid]
    component_name = (component_uuid, name)
    if !(component_name in record.component_names)
        throw(ArgumentError("$component_name wasn't stored for $uuid"))
    end

    pop!(record.component_names, component_name)
    @debug "Removed $component_name from $uuid."

    if isempty(record.component_names)
        @debug "$uuid has no more references; delete it."
        pop!(storage.data, uuid)
    end
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

    ts = storage.data[uuid].ts
    total_rows = length(ts_metadata)
    if rows.start == 1 && length(rows) == total_rows
        # No memory allocation
        return ts
    end

    # TimeArray doesn't support @view
    return T(ts, get_data(ts)[rows])
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

    ts = storage.data[uuid].ts
    if ts isa SingleTimeSeries
        return deserialize_deterministic_from_single_time_series(
            storage,
            ts_metadata,
            rows,
            columns,
            length(ts),
        )
    end

    total_rows = length(ts_metadata)
    total_columns = get_count(ts_metadata)
    if length(rows) == total_rows && length(columns) == total_columns
        return ts
    end

    full_data = get_data(ts)
    initial_timestamp = get_initial_timestamp(ts)
    resolution = get_resolution(ts)
    interval = get_interval(ts)
    start_time = initial_timestamp + interval * (columns.start - 1)
    data = SortedDict{Dates.DateTime, eltype(typeof(full_data)).parameters[2]}()
    for initial_time in range(start_time; step = interval, length = length(columns))
        if rows.start == 1
            it = initial_time
        else
            it = initial_time + (rows.start - 1) * resolution
        end
        data[it] = @view full_data[initial_time][rows]
    end

    if T isa AbstractDeterministic
        return Deterministic(ts, data)
    else
        return T(ts, data)
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
    for record in values(storage.data)
        for pair in record.component_names
            serialize_time_series!(hdf5_storage, pair[1], pair[2], record.ts)
        end
    end
end

function compare_values(x::InMemoryTimeSeriesStorage, y::InMemoryTimeSeriesStorage)::Bool
    keys_x = sort!(collect(keys(x.data)))
    keys_y = sort!(collect(keys(y.data)))
    if keys_x != keys_y
        @error "keys don't match" keys_x keys_y
        return false
    end

    for key in keys_x
        record_x = x.data[key]
        record_y = y.data[key]
        if record_x.component_names != record_y.component_names
            @error "component_names don't match" record_x.component_names record_y.component_names
            return false
        end
        if TimeSeries.timestamp(record_x.ta.data) != TimeSeries.timestamp(record_y.ta.data)
            @error "timestamps don't match" record_x record_y
            return false
        end
        if TimeSeries.values(record_x.ta.data) != TimeSeries.values(record_y.ta.data)
            @error "values don't match" record_x record_y
            return false
        end
    end

    return true
end
