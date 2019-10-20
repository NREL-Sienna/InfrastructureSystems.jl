
"""
Abstract type for time series storage implementations.

All subtypes must implement:
- add_time_series!
- remove_time_series!
- get_time_series
- clear_time_series!
- get_num_time_series
"""
abstract type TimeSeriesStorage end

function make_time_series_storage(; in_memory=false, filename=nothing)
    if in_memory
        storage = InMemoryTimeSeriesStorage()
    elseif !isnothing(filename)
        storage = Hdf5TimeSeriesStorage(; filename=filename)
    else
        storage = Hdf5TimeSeriesStorage()
    end

    return storage
end

function make_component_label(component_uuid::UUIDs.UUID, label::AbstractString)
    return string(component_uuid) * "_" * label
end

function serialize(storage::TimeSeriesStorage, file_path::AbstractString)
    if storage isa Hdf5TimeSeriesStorage
        # The data is currently in a temp file, so we can just make a copy.
        cp(get_file_path(storage), file_path; force=true)
    elseif storage isa InMemoryTimeSeriesStorage
        convert_to_hdf5(storage, file_path)
    else
        error("unsupported type $(typeof(storage))")
    end

    @info "Serialized time series data to $file_path."
end
