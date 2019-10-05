
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

function make_time_series_storage(; in_memory = false, filename = nothing)
    if in_memory
        storage = InMemoryTimeSeriesStorage()
    elseif !isnothing(filename)
        storage = Hdf5TimeSeriesStorage(; filename = filename)
    else
        storage = Hdf5TimeSeriesStorage()
    end

    return storage
end

function make_component_label(component::InfrastructureSystemsType, label::AbstractString)
    return string(get_uuid(component)) * "_" * label
end
