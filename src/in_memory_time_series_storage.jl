
const _ComponentLabelReferences = Set{Tuple{UUIDs.UUID, String}}

struct _TimeSeriesRecord
    component_labels::_ComponentLabelReferences
    ts::TimeSeriesData
end

function _TimeSeriesRecord(component_uuid, label, ts)
    record = _TimeSeriesRecord(_ComponentLabelReferences(), ts)
    push!(record.component_labels, (component_uuid, label))
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
    @info "Created InMemoryTimeSeriesStorage"
    return storage
end

function add_time_series!(
                          storage::InMemoryTimeSeriesStorage,
                          component::InfrastructureSystemsType,
                          label::AbstractString,
                          ts::TimeSeriesData,
                         )
    uuid = get_uuid(ts)
    if !haskey(storage.data, uuid)
        @debug "Create new time series entry." uuid get_uuid(component) label
        storage.data[uuid] = _TimeSeriesRecord(get_uuid(component), label, ts)
    else
        @debug "Add reference to existing time series entry." uuid get_uuid(component) label
        record = storage.data[uuid]
        push!(record.component_labels, (get_uuid(component), label))
    end
end

function remove_time_series!(
                             storage::InMemoryTimeSeriesStorage,
                             uuid::UUIDs.UUID,
                             component::InfrastructureSystemsType,
                             label::AbstractString,
                            )
    if !haskey(storage.data, uuid)
        throw(ArgumentError("$uuid is not stored"))
    end

    record = storage.data[uuid]
    component_label = (get_uuid(component), label)
    if !(component_label in record.component_labels)
        throw(ArgumentError("$component_label wasn't stored for $uuid"))
    end

    pop!(record.component_labels, component_label)
    @debug "Removed $component_label from $uuid."

    if isempty(record.component_labels)
        @debug "$uuid has no more references; delete it."
        pop!(storage.data, uuid)
    end
end

function get_time_series(
                         storage::InMemoryTimeSeriesStorage,
                         uuid::UUIDs.UUID;
                         index=0,
                         len=0,
                        )::TimeSeries.TimeArray
    if !haskey(storage.data, uuid)
        throw(ArgumentError("$uuid is not stored"))
    end

    if index != 0
        @assert len != 0
        end_index = index + len - 1
        return storage.data[uuid].ts.data[index:end_index]
    end

    return storage.data[uuid].ts.data
end

function clear_time_series!(storage::InMemoryTimeSeriesStorage)
    empty!(storage.data)
    @info "Cleared all time series."
end

function get_num_time_series(storage::InMemoryTimeSeriesStorage)
    return length(storage.data)
end

