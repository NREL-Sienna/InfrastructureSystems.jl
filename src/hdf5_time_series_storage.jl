
import HDF5
import H5Zblosc

const HDF5_TS_ROOT_PATH = "time_series"
const TIME_SERIES_DATA_FORMAT_VERSION = "1.0.1"
const TIME_SERIES_VERSION_KEY = "data_format_version"
const COMPONENT_REFERENCES_KEY = "component_references"

"""
Stores all time series data in an HDF5 file.

The file used is assumed to be temporary and will be automatically deleted when there are
no more references to the storage object.
"""
mutable struct Hdf5TimeSeriesStorage <: TimeSeriesStorage
    file_path::String
    read_only::Bool
    compression::CompressionSettings
end

"""
Constructs Hdf5TimeSeriesStorage by creating a temp file.
"""
function Hdf5TimeSeriesStorage()
    return Hdf5TimeSeriesStorage(true)
end

"""
Constructs Hdf5TimeSeriesStorage.

# Arguments

  - `create_file::Bool`: create new file
  - `filename=nothing`: if nothing, create a temp file, else use this name.
  - `directory=nothing`: if set and filename is nothing, create a temp file in this
    directory. Use tempdir() if not set. This should be set if the time series data is larger
    than the tmp filesystem can hold.
  - `read_only = false`: If true, don't allow changes to the file. Allows simultaneous read
    access.
"""
function Hdf5TimeSeriesStorage(
    create_file::Bool;
    filename = nothing,
    directory = nothing,
    read_only = false,
    compression = CompressionSettings(),
)
    if create_file
        if isnothing(filename)
            if isnothing(directory)
                directory = tempdir()
            end
            filename, io = mktemp(directory)
            close(io)
        end

        storage = Hdf5TimeSeriesStorage(filename, read_only, compression)
        _make_file(storage)
    else
        storage = Hdf5TimeSeriesStorage(filename, read_only, compression)
    end

    @debug "Constructed new Hdf5TimeSeriesStorage" _group = LOG_GROUP_TIME_SERIES storage.file_path read_only compression

    return storage
end

"""
Constructs Hdf5TimeSeriesStorage from an existing file.
"""
function from_file(
    ::Type{Hdf5TimeSeriesStorage},
    filename::AbstractString;
    read_only = false,
    directory = nothing,
)
    if !isfile(filename)
        error("time series storage $filename does not exist")
    end

    if read_only
        file_path = abspath(filename)
    else
        parent = isnothing(directory) ? tempdir() : directory
        file_path, io = mktemp(parent)
        close(io)
        copy_h5_file(filename, file_path)
    end

    storage = Hdf5TimeSeriesStorage(false; filename = file_path, read_only = read_only)
    if !read_only
        version = read_data_format_version(storage)
        if version == "1.0.0"
            _convert_from_1_0_0!(storage)
        end
        _deserialize_compression_settings!(storage)
    end

    @info "Loaded time series from storage file existing=$filename new=$(storage.file_path) compression=$(storage.compression)"
    return storage
end

function Base.isempty(storage::Hdf5TimeSeriesStorage)
    return HDF5.h5open(storage.file_path, "r+") do file
        root = _get_root(storage, file)
        return isempty(keys(root))
    end
end

"""
Copy the time series data to a new file. This should get called when the system is
undergoing a deepcopy.

# Arguments

  - `storage::Hdf5TimeSeriesStorage`: storage instance
  - `directory::String`: If nothing, use tempdir
"""
function copy_to_new_file!(storage::Hdf5TimeSeriesStorage, directory = nothing)
    if directory === nothing
        directory = tempdir()
    end

    # If we ever choose to keep the HDF5 file open then this will break.
    # Any open buffers will need to be flushed.
    filename, io = mktemp(directory)
    close(io)
    copy_h5_file(get_file_path(storage), filename)
    storage.file_path = filename
    return
end

"""
Copies an HDF5 file to a new file. This should be used instead of a system call to copy
because it won't copy unused space that results from deleting datasets.
"""
function copy_h5_file(src::AbstractString, dst::AbstractString)
    HDF5.h5open(dst, "w") do fw
        HDF5.h5open(src, "r") do fr
            HDF5.copy_object(fr[HDF5_TS_ROOT_PATH], fw, HDF5_TS_ROOT_PATH)
        end
    end

    return
end

get_compression_settings(storage::Hdf5TimeSeriesStorage) = storage.compression

get_file_path(storage::Hdf5TimeSeriesStorage) = storage.file_path

function read_data_format_version(storage::Hdf5TimeSeriesStorage)
    HDF5.h5open(storage.file_path, "r") do file
        root = _get_root(storage, file)
        if !haskey(HDF5.attributes(root), TIME_SERIES_VERSION_KEY)
            return "1.0.0"
        end
        return HDF5.read(HDF5.attributes(root)[TIME_SERIES_VERSION_KEY])
    end
end

function serialize_time_series!(
    storage::Hdf5TimeSeriesStorage,
    component_uuid::UUIDs.UUID,
    name::AbstractString,
    ts::TimeSeriesData,
)
    check_read_only(storage)
    uuid = string(get_uuid(ts))
    component_name = make_component_name(component_uuid, name)

    HDF5.h5open(storage.file_path, "r+") do file
        root = _get_root(storage, file)
        if !haskey(root, uuid)
            group = HDF5.create_group(root, uuid)
            # Create a group to store component references as attributes.
            # Use this instead of this time series' group or the dataset so that
            # the only attributes are component references.
            component_refs = HDF5.create_group(group, COMPONENT_REFERENCES_KEY)
            data = get_array_for_hdf(ts)
            settings = storage.compression
            if settings.enabled
                if settings.type == CompressionTypes.BLOSC
                    group["data", blosc = settings.level] = data
                elseif settings.type == CompressionTypes.DEFLATE
                    if settings.shuffle
                        group["data", shuffle = (), deflate = settings.level] = data
                    else
                        group["data", deflate = settings.level] = data
                    end
                else
                    error("not implemented for type=$(settings.type)")
                end
            else
                group["data"] = data
            end
            _write_time_series_attributes!(storage, ts, group)
            @debug "Create new time series entry." _group = LOG_GROUP_TIME_SERIES uuid component_uuid name
        else
            component_refs = root[uuid][COMPONENT_REFERENCES_KEY]
            @debug "Add reference to existing time series entry." _group =
                LOG_GROUP_TIME_SERIES uuid component_uuid name
        end
        HDF5.attributes(component_refs)[component_name] = true
        return
    end

    return
end

"""
Return a String for the data type of the forecast data, this implementation avoids the use of `eval` on arbitrary code stored in HDF dataset.
"""
function get_data_type(ts::TimeSeriesData)
    data_type = eltype_data(ts)
    if data_type <: CONSTANT
        return "CONSTANT"
    elseif data_type == POLYNOMIAL
        return "POLYNOMIAL"
    elseif data_type == PWL
        return "PWL"
    elseif data_type <: Integer
        # We currently don't convert integers stored in TimeSeries.TimeArrays to floats.
        # This is a workaround.
        return "CONSTANT"
    else
        error("$data_type is not supported in forecast data")
    end
end

function _write_time_series_attributes!(
    storage::Hdf5TimeSeriesStorage,
    ts::T,
    path,
) where {T <: StaticTimeSeries}
    return _write_time_series_attributes_common!(storage, ts, path)
end

function _write_time_series_attributes!(
    storage::Hdf5TimeSeriesStorage,
    ts::T,
    path,
) where {T <: Forecast}
    _write_time_series_attributes_common!(storage, ts, path)
    interval = get_interval(ts)
    HDF5.attributes(path)["interval"] = time_period_conversion(interval).value
    return
end

function _write_time_series_attributes_common!(storage::Hdf5TimeSeriesStorage, ts, path)
    initial_timestamp = Dates.datetime2epochms(get_initial_timestamp(ts))
    resolution = get_resolution(ts)
    data_type = get_data_type(ts)
    HDF5.attributes(path)["module"] = string(parentmodule(typeof(ts)))
    HDF5.attributes(path)["type"] = string(nameof(typeof(ts)))
    HDF5.attributes(path)["initial_timestamp"] = initial_timestamp
    HDF5.attributes(path)["resolution"] = time_period_conversion(resolution).value
    HDF5.attributes(path)["data_type"] = data_type
    return
end

function _read_time_series_attributes(
    storage::Hdf5TimeSeriesStorage,
    path,
    rows,
    ::Type{T},
) where {T <: StaticTimeSeries}
    return _read_time_series_attributes_common(storage, path, rows)
end

function _read_time_series_attributes(
    storage::Hdf5TimeSeriesStorage,
    path,
    rows,
    ::Type{T},
) where {T <: Forecast}
    data = _read_time_series_attributes_common(storage, path, rows)
    data["interval"] = Dates.Millisecond(HDF5.read(HDF5.attributes(path)["interval"]))
    return data
end

const _TYPE_DICT = Dict("CONSTANT" => CONSTANT, "POLYNOMIAL" => POLYNOMIAL, "PWL" => PWL)

function _read_time_series_attributes_common(storage::Hdf5TimeSeriesStorage, path, rows)
    initial_timestamp =
        Dates.epochms2datetime(HDF5.read(HDF5.attributes(path)["initial_timestamp"]))
    resolution = Dates.Millisecond(HDF5.read(HDF5.attributes(path)["resolution"]))
    data_type = _TYPE_DICT[HDF5.read(HDF5.attributes(path)["data_type"])]
    return Dict(
        "type" => _read_time_series_type(path),
        "initial_timestamp" => initial_timestamp,
        "resolution" => resolution,
        "dataset_size" => size(path["data"]),
        "start_time" => initial_timestamp + resolution * (rows.start - 1),
        "data_type" => data_type,
    )
end

function _read_time_series_type(path)
    module_str = HDF5.read(HDF5.attributes(path)["module"])
    type_str = HDF5.read(HDF5.attributes(path)["type"])
    return get_type_from_strings(module_str, type_str)
end

function add_time_series_reference!(
    storage::Hdf5TimeSeriesStorage,
    component_uuid::UUIDs.UUID,
    name::AbstractString,
    ts_uuid::UUIDs.UUID,
)
    check_read_only(storage)
    uuid = string(ts_uuid)
    component_name = make_component_name(component_uuid, name)
    HDF5.h5open(storage.file_path, "r+") do file
        root = _get_root(storage, file)
        path = root[uuid][COMPONENT_REFERENCES_KEY]

        # It's possible that this is overly restrictive, but as of now there is not a good
        # reason for a caller to add a reference multiple times. This should be a bug.
        @assert !haskey(HDF5.attributes(path), component_name) "There is already a reference to $component_name for time series $ts_uuid"

        HDF5.attributes(path)[component_name] = true
        @debug "Add reference to existing time series entry." _group = LOG_GROUP_TIME_SERIES uuid component_uuid name
    end
end

# TODO: This needs to change if we want to directly convert Hdf5TimeSeriesStorage to
# InMemoryTimeSeriesStorage, which is currently not supported at System deserialization.
function iterate_time_series(storage::Hdf5TimeSeriesStorage)
    Channel() do channel
        HDF5.h5open(storage.file_path, "r") do file
            root = _get_root(storage, file)
            for uuid_group in root
                data = uuid_group["data"][:]
                attributes = Dict()
                for name in keys(HDF5.attributes(uuid_group))
                    attributes[name] = HDF5.read(HDF5.attributes(uuid_group)[name])
                end
                refs = uuid_group[COMPONENT_REFERENCES_KEY]
                for ref in keys(HDF5.attributes(refs))
                    component, name = deserialize_component_name(ref)
                    put!(channel, (component, name, data, attributes))
                end
            end
        end
    end
end

#=
# This could be used if we deserialize the type directly from HDF.
function _make_rows_columns(dataset, ::Type{T}) where T <: StaticTimeSeries
    rows = UnitRange(1, size(dataset)[1])
    columns = UnitRange(1, 1)
    return (rows, columns)
end

function _make_rows_columns(dataset, ::Type{T}) where T <: Forecast
    rows = UnitRange(1, size(dataset)[1])
    columns = UnitRange(1, size(dataset)[2])
    return (rows, columns)
end
=#

function remove_time_series!(
    storage::Hdf5TimeSeriesStorage,
    uuid::UUIDs.UUID,
    component_uuid::UUIDs.UUID,
    name::AbstractString,
)
    check_read_only(storage)
    HDF5.h5open(storage.file_path, "r+") do file
        root = _get_root(storage, file)
        path = _get_time_series_path(root, uuid)
        components = path[COMPONENT_REFERENCES_KEY]
        HDF5.delete_attribute(components, make_component_name(component_uuid, name))
        if isempty(keys(HDF5.attributes(components)))
            @debug "$path has no more references; delete it." _group = LOG_GROUP_TIME_SERIES
            HDF5.delete_object(path)
        end
    end
end

function deserialize_time_series(
    ::Type{T},
    storage::Hdf5TimeSeriesStorage,
    ts_metadata::TimeSeriesMetadata,
    rows::UnitRange,
    columns::UnitRange,
) where {T <: StaticTimeSeries}
    # Note that all range checks must occur at a higher level.
    return HDF5.h5open(storage.file_path, "r") do file
        root = _get_root(storage, file)
        uuid = get_time_series_uuid(ts_metadata)
        path = _get_time_series_path(root, uuid)
        attributes = _read_time_series_attributes(storage, path, rows, T)
        @assert_op attributes["type"] == T
        @debug "deserializing a StaticTimeSeries" _group = LOG_GROUP_TIME_SERIES T
        data_type = attributes["data_type"]
        data = get_hdf_array(path["data"], data_type, rows)
        return T(
            ts_metadata,
            TimeSeries.TimeArray(
                range(
                    attributes["start_time"];
                    length = length(rows),
                    step = attributes["resolution"],
                ),
                data,
            ),
        )
    end
end

function deserialize_time_series(
    ::Type{T},
    storage::Hdf5TimeSeriesStorage,
    ts_metadata::TimeSeriesMetadata,
    rows::UnitRange,
    columns::UnitRange,
) where {T <: AbstractDeterministic}
    # Note that all range checks must occur at a higher level.
    return HDF5.h5open(storage.file_path, "r") do file
        root = _get_root(storage, file)
        uuid = get_time_series_uuid(ts_metadata)
        path = _get_time_series_path(root, uuid)
        actual_type = _read_time_series_type(path)
        if actual_type == SingleTimeSeries
            last_index = size(path["data"])[1]
            return deserialize_deterministic_from_single_time_series(
                storage,
                ts_metadata,
                rows,
                columns,
                last_index,
            )
        end

        attributes = _read_time_series_attributes(storage, path, rows, T)
        @assert actual_type <: T "actual_type = $actual_type T = $T"
        @debug "deserializing a Forecast" _group = LOG_GROUP_TIME_SERIES T
        data_type = attributes["data_type"]
        data = get_hdf_array(path["data"], data_type, attributes, rows, columns)
        return actual_type(ts_metadata, data)
    end
end

function get_hdf_array(
    dataset,
    ::Type{<:CONSTANT},
    attributes::Dict{String, Any},
    rows::UnitRange{Int},
    columns::UnitRange{Int},
)
    data = SortedDict{Dates.DateTime, Vector{Float64}}()
    initial_timestamp = attributes["start_time"]
    interval = attributes["interval"]
    start_time = initial_timestamp + interval * (columns.start - 1)
    if length(columns) == 1
        data[start_time] = dataset[rows, columns.start]
    else
        data_read = dataset[rows, columns]
        for (i, it) in
            enumerate(range(start_time; length = length(columns), step = interval))
            data[it] = @view data_read[1:length(rows), i]
        end
    end
    return data
end

function get_hdf_array(
    dataset,
    type::Type{POLYNOMIAL},
    attributes::Dict{String, Any},
    rows::UnitRange{Int},
    columns::UnitRange{Int},
)
    data = SortedDict{Dates.DateTime, Vector{POLYNOMIAL}}()
    initial_timestamp = attributes["start_time"]
    interval = attributes["interval"]
    start_time = initial_timestamp + interval * (columns.start - 1)
    if length(columns) == 1
        data[start_time] = retransform_hdf_array(dataset[rows, columns.start, :], type)
    else
        data_read = retransform_hdf_array(dataset[rows, columns, :], type)
        for (i, it) in
            enumerate(range(start_time; length = length(columns), step = interval))
            data[it] = @view data_read[1:length(rows), i]
        end
    end
    return data
end

function get_hdf_array(
    dataset,
    type::Type{PWL},
    attributes::Dict{String, Any},
    rows::UnitRange{Int},
    columns::UnitRange{Int},
)
    data = SortedDict{Dates.DateTime, Vector{PWL}}()
    initial_timestamp = attributes["start_time"]
    interval = attributes["interval"]
    start_time = initial_timestamp + interval * (columns.start - 1)
    if length(columns) == 1
        data[start_time] = retransform_hdf_array(dataset[rows, columns.start, :, :], type)
    else
        data_read = retransform_hdf_array(dataset[rows, columns, :, :], type)
        for (i, it) in
            enumerate(range(start_time; length = length(columns), step = interval))
            data[it] = @view data_read[1:length(rows), i]
        end
    end
    return data
end

function get_hdf_array(dataset, type::Type{<:CONSTANT}, rows::UnitRange{Int})
    data = retransform_hdf_array(dataset[rows], type)
    return data
end

function get_hdf_array(dataset, type::Type{POLYNOMIAL}, rows::UnitRange{Int})
    data = retransform_hdf_array(dataset[rows, :, :], type)
    return data
end

function get_hdf_array(dataset, type::Type{PWL}, rows::UnitRange{Int})
    data = retransform_hdf_array(dataset[rows, :, :, :], type)
    return data
end

function retransform_hdf_array(data::Array, ::Type{<:CONSTANT})
    return data
end

function retransform_hdf_array(data::Array, T::Type{POLYNOMIAL})
    row, column, tuple_length = get_data_dims(data, T)
    if isnothing(column)
        t_data = Array{POLYNOMIAL}(undef, row)
        for r in 1:row
            t_data[r] = tuple(data[r, 1:tuple_length]...)
        end
    else
        t_data = Array{POLYNOMIAL}(undef, row, column)
        for r in 1:row, c in 1:column
            t_data[r, c] = tuple(data[r, c, 1:tuple_length]...)
        end
    end
    return t_data
end

function retransform_hdf_array(data::Array, T::Type{PWL})
    row, column, tuple_length, array_length = get_data_dims(data, T)
    if isnothing(column)
        t_data = Array{PWL}(undef, row)
        for r in 1:row
            tuple_array = Array{POLYNOMIAL}(undef, array_length)
            for l in 1:array_length
                tuple_array[l] = tuple(data[r, 1:tuple_length, l]...)
            end
            t_data[r] = tuple_array
        end
    else
        t_data = Array{PWL}(undef, row, column)
        for r in 1:row, c in 1:column
            tuple_array = Array{POLYNOMIAL}(undef, array_length)
            for l in 1:array_length
                tuple_array[l] = tuple(data[r, c, 1:tuple_length, l]...)
            end
            t_data[r, c] = tuple_array
        end
    end
    return t_data
end

function get_data_dims(data::Array, ::Type{POLYNOMIAL})
    if length(size(data)) == 2
        row, tuple_length = size(data)
        return (row, nothing, tuple_length)
    elseif length(size(data)) == 3
        return size(data)
    else
        error("Hdf data array is $(length(size(data)))-D array, expected 2-D or 3-D array.")
    end
end

function get_data_dims(data::Array, ::Type{PWL})
    if length(size(data)) == 3
        row, tuple_length, array_length = size(data)
        return (row, nothing, tuple_length, array_length)
    elseif length(size(data)) == 4
        return size(data)
    else
        error("Hdf data array is $(length(size(data)))-D array, expected 3-D or 4-D array.")
    end
end

function deserialize_time_series(
    ::Type{T},
    storage::Hdf5TimeSeriesStorage,
    ts_metadata::TimeSeriesMetadata,
    rows::UnitRange,
    columns::UnitRange,
) where {T <: Probabilistic}
    # Note that all range checks must occur at a higher level.
    total_percentiles = length(get_percentiles(ts_metadata))

    return HDF5.h5open(storage.file_path, "r") do file
        root = _get_root(storage, file)
        uuid = get_time_series_uuid(ts_metadata)
        path = _get_time_series_path(root, uuid)
        attributes = _read_time_series_attributes(storage, path, rows, T)
        @assert_op attributes["type"] == T
        @assert_op length(attributes["dataset_size"]) == 3
        @debug "deserializing a Forecast" _group = LOG_GROUP_TIME_SERIES T
        data = SortedDict{Dates.DateTime, Matrix{attributes["data_type"]}}()
        initial_timestamp = attributes["start_time"]
        interval = attributes["interval"]
        start_time = initial_timestamp + interval * (first(columns) - 1)
        if length(columns) == 1
            data[start_time] =
                transpose(path["data"][1:total_percentiles, rows, first(columns)])
        else
            data_read = PermutedDimsArray(
                path["data"][1:total_percentiles, rows, columns],
                [3, 2, 1],
            )
            for (i, it) in enumerate(
                range(start_time; length = length(columns), step = attributes["interval"]),
            )
                data[it] = @view data_read[i, 1:length(rows), 1:total_percentiles]
            end
        end

        return T(ts_metadata, data)
    end
end

function deserialize_time_series(
    ::Type{T},
    storage::Hdf5TimeSeriesStorage,
    ts_metadata::TimeSeriesMetadata,
    rows::UnitRange,
    columns::UnitRange,
) where {T <: Scenarios}
    # Note that all range checks must occur at a higher level.
    total_scenarios = get_scenario_count(ts_metadata)

    return HDF5.h5open(storage.file_path, "r") do file
        root = _get_root(storage, file)
        uuid = get_time_series_uuid(ts_metadata)
        path = _get_time_series_path(root, uuid)
        attributes = _read_time_series_attributes(storage, path, rows, T)
        @assert_op attributes["type"] == T
        @assert_op length(attributes["dataset_size"]) == 3
        @debug "deserializing a Forecast" _group = LOG_GROUP_TIME_SERIES T
        data = SortedDict{Dates.DateTime, Matrix{attributes["data_type"]}}()
        initial_timestamp = attributes["start_time"]
        interval = attributes["interval"]
        start_time = initial_timestamp + interval * (first(columns) - 1)
        if length(columns) == 1
            data[start_time] =
                transpose(path["data"][1:total_scenarios, rows, first(columns)])
        else
            data_read =
                PermutedDimsArray(path["data"][1:total_scenarios, rows, columns], [3, 2, 1])
            for (i, it) in enumerate(
                range(start_time; length = length(columns), step = attributes["interval"]),
            )
                data[it] = @view data_read[i, 1:length(rows), 1:total_scenarios]
            end
        end

        return T(ts_metadata, data)
    end
end

function clear_time_series!(storage::Hdf5TimeSeriesStorage)
    check_read_only(storage)
    # Re-create the file. HDF5 will not actually free up the deleted space until h5repack
    # is run on the file.
    _make_file(storage)
    @info "Cleared all time series."
end

function get_num_time_series(storage::Hdf5TimeSeriesStorage)
    num = 0

    HDF5.h5open(storage.file_path, "r") do file
        root = _get_root(storage, file)
        for component in root
            num += 1
        end
    end

    return num
end

function replace_component_uuid!(
    storage::Hdf5TimeSeriesStorage,
    ts_uuid,
    old_component_uuid,
    new_component_uuid,
    name,
)
    check_read_only(storage)
    HDF5.h5open(storage.file_path, "r+") do file
        root = _get_root(storage, file)
        path = _get_time_series_path(root, ts_uuid)
        components = path[COMPONENT_REFERENCES_KEY]
        HDF5.delete_attribute(components, make_component_name(old_component_uuid, name))
        new_component_name = make_component_name(new_component_uuid, name)
        if haskey(HDF5.attributes(components), new_component_name)
            error("BUG! $new_component_name is already stored in time series $ts_uuid")
        end

        HDF5.attributes(components)[new_component_name] = true
        return
    end
end

function _make_file(storage::Hdf5TimeSeriesStorage)
    HDF5.h5open(storage.file_path, "w") do file
        root = HDF5.create_group(file, HDF5_TS_ROOT_PATH)
        HDF5.attributes(root)[TIME_SERIES_VERSION_KEY] = TIME_SERIES_DATA_FORMAT_VERSION
        _serialize_compression_settings(storage, root)
        return
    end
end

function _serialize_compression_settings(storage::Hdf5TimeSeriesStorage, root)
    HDF5.attributes(root)["compression_enabled"] = storage.compression.enabled
    HDF5.attributes(root)["compression_type"] = string(storage.compression.type)
    HDF5.attributes(root)["compression_level"] = storage.compression.level
    HDF5.attributes(root)["compression_shuffle"] = storage.compression.shuffle
    return
end

function _deserialize_compression_settings!(storage::Hdf5TimeSeriesStorage)
    HDF5.h5open(storage.file_path, "r+") do file
        root = _get_root(storage, file)
        storage.compression = CompressionSettings(;
            enabled = HDF5.read(HDF5.attributes(root)["compression_enabled"]),
            type = CompressionTypes(HDF5.read(HDF5.attributes(root)["compression_type"])),
            level = HDF5.read(HDF5.attributes(root)["compression_level"]),
            shuffle = HDF5.read(HDF5.attributes(root)["compression_shuffle"]),
        )
        return
    end
    return
end

_get_root(storage::Hdf5TimeSeriesStorage, file) = file[HDF5_TS_ROOT_PATH]

function _get_time_series_path(root::HDF5.Group, uuid::UUIDs.UUID)
    uuid_str = string(uuid)
    if !haskey(root, uuid_str)
        throw(ArgumentError("UUID $uuid_str does not exist"))
    end

    return root[uuid_str]
end

function check_read_only(storage::Hdf5TimeSeriesStorage)
    if storage.read_only
        error("Operation not permitted; this time series file is read-only")
    end
end

is_read_only(storage::Hdf5TimeSeriesStorage) = storage.read_only

function compare_values(
    x::Hdf5TimeSeriesStorage,
    y::Hdf5TimeSeriesStorage;
    compare_uuids = false,
)
    item_x = sort!(collect(iterate_time_series(x)); by = z -> z[1])
    item_y = sort!(collect(iterate_time_series(y)); by = z -> z[1])
    if length(item_x) != length(item_y)
        @error "lengths don't match" length(item_x) length(item_y)
        return false
    end

    if !compare_uuids
        # TODO: This could be improved. But we still get plenty of verification when
        # UUIDs are not changed.
        return true
    end

    for ((uuid_x, name_x, data_x, attrs_x), (uuid_y, name_y, data_y, attrs_y)) in
        zip(item_x, item_y)
        if uuid_x != uuid_y
            @error "component UUIDs don't match" uuid_x uuid_y
            return false
        end
        if name_x != name_y
            @error "names don't match" name_x name_y
            return false
        end
        if data_x != data_y
            @error "data doesn't match" data_x data_y
            return false
        end
        if sort!(collect(keys(attrs_x))) != sort!(collect(keys(attrs_y)))
            @error "attr keys don't match" attrs_x attrs_y
        end
        if collect(values(attrs_x)) != collect(values(attrs_y))
            @error "attr values don't match" attrs_x attrs_y
        end
    end

    return true
end

function _convert_from_1_0_0!(storage::Hdf5TimeSeriesStorage)
    # 1.0.0 version did not support compression.
    # 1.0.0 stored component name/UUID pairs in a dataset.
    # That wasn't efficient if a user added many shared references.
    HDF5.h5open(storage.file_path, "r+") do file
        root = _get_root(storage, file)
        for uuid_group in root
            components = HDF5.create_group(uuid_group, COMPONENT_REFERENCES_KEY)
            component_names = uuid_group["components"][:]
            for name in component_names
                HDF5.attributes(components)[name] = true
            end
            HDF5.delete_object(uuid_group["components"])
        end

        HDF5.attributes(root)[TIME_SERIES_VERSION_KEY] = TIME_SERIES_DATA_FORMAT_VERSION
        compression = CompressionSettings()
        _serialize_compression_settings(storage, root)
        return
    end

    @debug "Converted file from 1.0.0 format" _group = LOG_GROUP_TIME_SERIES
end
