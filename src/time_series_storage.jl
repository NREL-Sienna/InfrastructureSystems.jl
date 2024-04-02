
"""
Abstract type for time series storage implementations.

All subtypes must implement:

  - check_read_only
  - clear_time_series!
  - deserialize_time_series
  - get_compression_settings
  - get_num_time_series
  - is_read_only
  - remove_time_series!
  - serialize_time_series!
  - replace_component_uuid!
  - Base.isempty
"""
abstract type TimeSeriesStorage end

const DEFAULT_COMPRESSION = false

@scoped_enum(CompressionTypes, BLOSC = 0, DEFLATE = 1,)

"""
Provides customization of HDF5 compression settings.
Refer to the HDF5.jl and HDF5 documention for more information.
"""
struct CompressionSettings
    "Controls whether compression is enabled."
    enabled::Bool
    "Specifies the type of compression to use."
    type::CompressionTypes
    "Supported values are 0-9. Higher values deliver better compression ratios but take longer."
    level::Int
    "Controls whether to enable the shuffle filter. Used with DEFLATE."
    shuffle::Bool
end

function CompressionSettings(;
    enabled = DEFAULT_COMPRESSION,
    type = CompressionTypes.DEFLATE,
    level = 3,
    shuffle = true,
)
    return CompressionSettings(enabled, type, level, shuffle)
end

function make_time_series_storage(;
    in_memory = false,
    filename = nothing,
    directory = nothing,
    compression = CompressionSettings(),
)
    if in_memory
        storage = InMemoryTimeSeriesStorage()
    elseif !isnothing(filename)
        storage = Hdf5TimeSeriesStorage(; filename = filename, compression = compression)
    else
        storage =
            Hdf5TimeSeriesStorage(true; directory = directory, compression = compression)
    end

    return storage
end

const COMPONENT_name_DELIMITER = "__"

function make_component_name(component_uuid::UUIDs.UUID, name::AbstractString)
    return string(component_uuid) * COMPONENT_name_DELIMITER * name
end

function deserialize_component_name(component_name::AbstractString)
    data = split(component_name, COMPONENT_name_DELIMITER)
    component = UUIDs.UUID(data[1])
    name = data[2]
    return component, name
end

function serialize(storage::TimeSeriesStorage, file_path::AbstractString)
    if storage isa Hdf5TimeSeriesStorage
        if abspath(get_file_path(storage)) == abspath(file_path)
            error("Attempting to overwrite identical time series file")
        end

        copy_h5_file(get_file_path(storage), file_path)
    elseif storage isa InMemoryTimeSeriesStorage
        convert_to_hdf5(storage, file_path)
    else
        error("unsupported type $(typeof(storage))")
    end

    @info "Serialized time series data to $file_path."
end
