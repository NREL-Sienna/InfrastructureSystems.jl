
"""
Abstract type for time series storage implementations.

All subtypes must implement:
- add_time_series!
- add_time_series_reference!
- remove_time_series!
- get_time_series
- clear_time_series!
- get_num_time_series
- check_read_only
"""
abstract type TimeSeriesStorage end

function make_time_series_storage(;
    in_memory = false,
    filename = nothing,
    directory = nothing,
)
    if in_memory
        storage = InMemoryTimeSeriesStorage()
    elseif !isnothing(filename)
        storage = Hdf5TimeSeriesStorage(; filename = filename)
    else
        storage = Hdf5TimeSeriesStorage(true; directory = directory)
    end

    return storage
end

const COMPONENT_LABEL_DELIMITER = "__"

function make_component_label(component_uuid::UUIDs.UUID, label::AbstractString)
    return string(component_uuid) * COMPONENT_LABEL_DELIMITER * label
end

function deserialize_component_label(component_label::AbstractString)
    data = split(component_label, COMPONENT_LABEL_DELIMITER)
    component = UUIDs.UUID(data[1])
    label = data[2]
    return component, label
end

function serialize(storage::TimeSeriesStorage, file_path::AbstractString)
    if storage isa Hdf5TimeSeriesStorage
        # The data is currently in a temp file, so we can just make a copy.
        run(`cp -f $(get_file_path(storage)) $(file_path)`)
    elseif storage isa InMemoryTimeSeriesStorage
        convert_to_hdf5(storage, file_path)
    else
        error("unsupported type $(typeof(storage))")
    end

    @info "Serialized time series data to $file_path."
end
