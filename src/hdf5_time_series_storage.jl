
import HDF5
import H5Zblosc

const HDF5_TS_ROOT_PATH = "time_series"
const HDF5_TS_METADATA_ROOT_PATH = "time_series_metadata"
const TIME_SERIES_DATA_FORMAT_VERSION = "2.0.0"
const TIME_SERIES_VERSION_KEY = "data_format_version"

"""
Stores all time series data in an HDF5 file.

The file used is assumed to be temporary and will be automatically deleted when there are
no more references to the storage object.
"""
mutable struct Hdf5TimeSeriesStorage <: TimeSeriesStorage
    file_path::String
    compression::CompressionSettings
    file::Union{Nothing, HDF5.File}
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
    directory. If it is not set, use the environment variable SIENNA_TIME_SERIES_DIRECTORY.
    If that is not set, use tempdir(). This should be set if the time series data is larger
    than the tmp filesystem can hold.
"""
function Hdf5TimeSeriesStorage(
    create_file::Bool;
    filename = nothing,
    directory = nothing,
    compression = CompressionSettings(),
)
    if create_file
        if isnothing(filename)
            directory = _get_time_series_parent_dir(directory)
            filename, io = mktemp(directory)
            close(io)
        end

        storage = Hdf5TimeSeriesStorage(filename, compression, nothing)
        _make_file(storage)
    else
        storage = Hdf5TimeSeriesStorage(filename, compression, nothing)
    end

    @debug "Constructed new Hdf5TimeSeriesStorage" _group = LOG_GROUP_TIME_SERIES storage.file_path compression

    return storage
end

function open_store!(
    func::Function,
    storage::Hdf5TimeSeriesStorage,
    mode = "r",
    args...;
    kwargs...,
)
    HDF5.h5open(storage.file_path, mode) do file
        storage.file = file
        try
            func(args...; kwargs...)
        finally
            storage.file = nothing
        end
    end
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
        parent = _get_time_series_parent_dir(directory)
        file_path, io = mktemp(parent)
        close(io)
        copy_h5_file(filename, file_path)
    end

    storage = Hdf5TimeSeriesStorage(false; filename = file_path)
    if !read_only
        _deserialize_compression_settings!(storage)
    end

    @info "Loaded time series from storage file existing=$filename new=$(storage.file_path) compression=$(storage.compression)"
    return storage
end

function _get_time_series_parent_dir(directory = nothing)
    # Ensure that a user-passed directory has highest precedence.
    if !isnothing(directory)
        if !isdir(directory)
            error("User passed time series directory, $directory, does not exist.")
        end
        return directory
    end

    directory = get(ENV, "SIENNA_TIME_SERIES_DIRECTORY", nothing)
    if !isnothing(directory)
        if !isdir(directory)
            error(
                "The directory specified by the environment variable " *
                "SIENNA_TIME_SERIES_DIRECTORY, $directory, does not exist.",
            )
        end
        @debug "Use time series directory specified by the environment variable" _group =
            LOG_GROUP_TIME_SERIES directory
        return directory
    end

    return tempdir()
end

Base.isempty(storage::Hdf5TimeSeriesStorage) = _isempty(storage, storage.file)

function _isempty(storage::Hdf5TimeSeriesStorage, ::Nothing)
    return HDF5.h5open(storage.file_path, "r") do file
        _isempty(storage, file)
    end
end

function _isempty(storage::Hdf5TimeSeriesStorage, file::HDF5.File)
    root = _get_root(storage, file)
    return isempty(keys(root))
end

"""
Copy the time series data to a new file. This should get called when the system is
undergoing a deepcopy.

# Arguments

  - `storage::Hdf5TimeSeriesStorage`: storage instance
  - `directory::String`: If nothing, use the directory specified by the environment variable
     SIENNA_TIME_SERIES_DIRECTORY or the system tempdir.
"""
function copy_to_new_file!(storage::Hdf5TimeSeriesStorage, directory = nothing)
    directory = _get_time_series_parent_dir(directory)

    if !isnothing(storage.file) && isopen(storage.file)
        error("This operation is not allowed when the HDF5 file handle is open.")
    end
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
            if HDF5_TS_METADATA_ROOT_PATH in keys(fr)
                HDF5.copy_object(
                    fr[HDF5_TS_METADATA_ROOT_PATH],
                    fw,
                    HDF5_TS_METADATA_ROOT_PATH,
                )
            end
        end
    end

    return
end

get_compression_settings(storage::Hdf5TimeSeriesStorage) = storage.compression

get_file_path(storage::Hdf5TimeSeriesStorage) = storage.file_path

function read_data_format_version(storage::Hdf5TimeSeriesStorage)
    return _read_data_format_version(storage, storage.file)
end

function _read_data_format_version(storage::Hdf5TimeSeriesStorage, ::Nothing)
    HDF5.h5open(storage.file_path, "r") do file
        return _read_data_format_version(storage, file)
    end
end

function _read_data_format_version(storage::Hdf5TimeSeriesStorage, file::HDF5.File)
    root = _get_root(storage, file)
    return HDF5.read(HDF5.attributes(root)[TIME_SERIES_VERSION_KEY])
end

function serialize_time_series!(
    storage::Hdf5TimeSeriesStorage,
    ts::TimeSeriesData,
)
    _serialize_time_series!(storage, ts, storage.file)
    return
end

function _serialize_time_series!(
    storage::Hdf5TimeSeriesStorage,
    ts::TimeSeriesData,
    ::Nothing,
)
    HDF5.h5open(storage.file_path, "r+") do file
        _serialize_time_series!(storage, ts, file)
    end
    return
end

function _serialize_time_series!(
    storage::Hdf5TimeSeriesStorage,
    ts::TimeSeriesData,
    file::HDF5.File,
)
    root = _get_root(storage, file)
    uuid = string(get_uuid(ts))
    if !haskey(root, uuid)
        group = HDF5.create_group(root, uuid)
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
        _write_time_series_attributes!(ts, group)
        @debug "Create new time series entry." _group = LOG_GROUP_TIME_SERIES uuid
    end
    return
end

"""
Return a String for the data type of the forecast data, this implementation avoids the use of `eval` on arbitrary code stored in HDF dataset.
"""
function get_data_type(ts::TimeSeriesData)
    data_type = eltype_data(ts)
    ((data_type <: CONSTANT) || (data_type <: Integer)) && (return "CONSTANT")
    (data_type <: FunctionData) && (return string(nameof(data_type)))
    error("$data_type is not supported in forecast data")
end

function _write_time_series_attributes!(
    ts::T,
    path,
) where {T <: TimeSeriesData}
    data_type = get_data_type(ts)
    HDF5.attributes(path)["module"] = string(parentmodule(typeof(ts)))
    HDF5.attributes(path)["type"] = string(nameof(typeof(ts)))
    HDF5.attributes(path)["data_type"] = data_type
    return
end

function _read_time_series_attributes(path)
    return Dict(
        "type" => _read_time_series_type(path),
        "dataset_size" => size(path["data"]),
        "data_type" => _TYPE_DICT[HDF5.read(HDF5.attributes(path)["data_type"])],
    )
end

# TODO I suspect this could be designed better using reflection even without the security risks of eval discussed above
const _TYPE_DICT = Dict(
    string(nameof(st)) => st for st in [
        LinearFunctionData,
        QuadraticFunctionData,
        PolynomialFunctionData,
        PiecewiseLinearPointData,
        PiecewiseLinearSlopeData,
    ]
)
_TYPE_DICT["CONSTANT"] = CONSTANT

function _read_time_series_type(path)
    module_str = HDF5.read(HDF5.attributes(path)["module"])
    type_str = HDF5.read(HDF5.attributes(path)["type"])
    return get_type_from_strings(module_str, type_str)
end

# TODO: This needs to change if we want to directly convert Hdf5TimeSeriesStorage to
# InMemoryTimeSeriesStorage, which is currently not supported at System deserialization.
function iterate_time_series(storage::Hdf5TimeSeriesStorage)
    Channel() do channel
        HDF5.h5open(storage.file_path, "r") do file
            root = _get_root(storage, file)
            for uuid in keys(root)
                data = HDF5.read(root[uuid]["data"])
                put!(channel, (Base.UUID(uuid), data))
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

function remove_time_series!(storage::Hdf5TimeSeriesStorage, uuid::UUIDs.UUID)
    _remove_time_series!(storage, uuid, storage.file)
end

function _remove_time_series!(
    storage::Hdf5TimeSeriesStorage,
    uuid::UUIDs.UUID,
    ::Nothing,
)
    HDF5.h5open(storage.file_path, "r+") do file
        _remove_time_series!(storage, uuid, file)
    end
end

function _remove_time_series!(
    storage::Hdf5TimeSeriesStorage,
    uuid::UUIDs.UUID,
    file::HDF5.File,
)
    root = _get_root(storage, file)
    path = _get_time_series_path(root, uuid)
    HDF5.delete_object(path)
    return
end

function deserialize_time_series(
    ::Type{T},
    storage::Hdf5TimeSeriesStorage,
    metadata::TimeSeriesMetadata,
    rows::UnitRange,
    columns::UnitRange,
) where {T <: StaticTimeSeries}
    _deserialize_time_series(T, storage, metadata, rows, columns, storage.file)
end

function _deserialize_time_series(
    ::Type{T},
    storage::Hdf5TimeSeriesStorage,
    metadata::TimeSeriesMetadata,
    rows::UnitRange,
    columns::UnitRange,
    ::Nothing,
) where {T <: StaticTimeSeries}
    return HDF5.h5open(storage.file_path, "r") do file
        _deserialize_time_series(T, storage, metadata, rows, columns, file)
    end
end

function _deserialize_time_series(
    ::Type{T},
    storage::Hdf5TimeSeriesStorage,
    metadata::TimeSeriesMetadata,
    rows::UnitRange,
    columns::UnitRange,
    file::HDF5.File,
) where {T <: StaticTimeSeries}
    # Note that all range checks must occur at a higher level.
    root = _get_root(storage, file)
    uuid = get_time_series_uuid(metadata)
    path = _get_time_series_path(root, uuid)
    attributes = _read_time_series_attributes(path)
    @debug "deserializing a StaticTimeSeries" _group = LOG_GROUP_TIME_SERIES T
    data_type = attributes["data_type"]
    data = get_hdf_array(path["data"], data_type, rows)
    resolution = get_resolution(metadata)
    start_time = get_initial_timestamp(metadata) + resolution * (rows.start - 1)
    timestamps = range(
        start_time;
        length = length(rows),
        step = resolution,
    )
    return T(metadata, TimeSeries.TimeArray(timestamps, data))
end

function deserialize_time_series(
    ::Type{T},
    storage::Hdf5TimeSeriesStorage,
    metadata::TimeSeriesMetadata,
    rows::UnitRange,
    columns::UnitRange,
) where {T <: AbstractDeterministic}
    # Note that all range checks must occur at a higher level.
    _deserialize_time_series(T, storage, metadata, rows, columns, storage.file)
end

function _deserialize_time_series(
    ::Type{T},
    storage::Hdf5TimeSeriesStorage,
    metadata::TimeSeriesMetadata,
    rows::UnitRange,
    columns::UnitRange,
    ::Nothing,
) where {T <: AbstractDeterministic}
    return HDF5.h5open(storage.file_path, "r") do file
        _deserialize_time_series(T, storage, metadata, rows, columns, file)
    end
end

function _deserialize_time_series(
    ::Type{T},
    storage::Hdf5TimeSeriesStorage,
    metadata::TimeSeriesMetadata,
    rows::UnitRange,
    columns::UnitRange,
    file::HDF5.File,
) where {T <: AbstractDeterministic}
    root = _get_root(storage, file)
    uuid = get_time_series_uuid(metadata)
    path = _get_time_series_path(root, uuid)
    actual_type = _read_time_series_type(path)
    if actual_type === SingleTimeSeries
        last_index = size(path["data"])[1]
        return deserialize_deterministic_from_single_time_series(
            storage,
            metadata,
            rows,
            columns,
            last_index,
        )
    end

    @assert actual_type <: T "actual_type = $actual_type T = $T"
    @debug "deserializing a Forecast" _group = LOG_GROUP_TIME_SERIES T
    attributes = _read_time_series_attributes(path)
    data = get_hdf_array(path["data"], attributes["data_type"], metadata, rows, columns)
    return actual_type(metadata, data)
end

function get_hdf_array(
    dataset,
    ::Type{<:CONSTANT},
    metadata::ForecastMetadata,
    rows::UnitRange{Int},
    columns::UnitRange{Int},
)
    data = SortedDict{Dates.DateTime, Vector{Float64}}()
    resolution = get_resolution(metadata)
    initial_timestamp = get_initial_timestamp(metadata) + resolution * (rows.start - 1)
    interval = get_interval(metadata)
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
    ::Type{LinearFunctionData},
    metadata::TimeSeriesMetadata,
    rows::UnitRange{Int},
    columns::UnitRange{Int},
)
    data = get_hdf_array(dataset, CONSTANT, metadata, rows, columns)
    return SortedDict{Dates.DateTime, Vector{LinearFunctionData}}(
        k => LinearFunctionData.(v) for (k, v) in data
    )
end

_quadratic_from_tuple((a, b)::Tuple{Float64, Float64}) = QuadraticFunctionData(a, b, 0.0)

function get_hdf_array(
    dataset,
    type::Type{QuadraticFunctionData},
    metadata::ForecastMetadata,
    rows::UnitRange{Int},
    columns::UnitRange{Int},
)
    data = SortedDict{Dates.DateTime, Vector{QuadraticFunctionData}}()
    resolution = get_resolution(metadata)
    initial_timestamp = get_initial_timestamp(metadata) + resolution * (rows.start - 1)
    interval = get_interval(metadata)
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
    type::Type{PiecewiseLinearPointData},
    metadata::ForecastMetadata,
    rows::UnitRange{Int},
    columns::UnitRange{Int},
)
    data = SortedDict{Dates.DateTime, Vector{PiecewiseLinearPointData}}()
    resolution = get_resolution(metadata)
    initial_timestamp = get_initial_timestamp(metadata) + resolution * (rows.start - 1)
    interval = get_interval(metadata)
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

function get_hdf_array(
    dataset,
    type::Union{Type{<:CONSTANT}, Type{LinearFunctionData}},
    rows::UnitRange{Int},
)
    data = retransform_hdf_array(dataset[rows], type)
    return data
end

function get_hdf_array(dataset, type::Type{QuadraticFunctionData}, rows::UnitRange{Int})
    data = retransform_hdf_array(dataset[rows, :, :], type)
    return data
end

function get_hdf_array(dataset, type::Type{PiecewiseLinearPointData}, rows::UnitRange{Int})
    data = retransform_hdf_array(dataset[rows, :, :, :], type)
    return data
end

function retransform_hdf_array(data::Array, ::Type{<:CONSTANT})
    return data
end

function retransform_hdf_array(data::Array, ::Type{LinearFunctionData})
    return LinearFunctionData.(data)
end

function retransform_hdf_array(data::Array, T::Type{QuadraticFunctionData})
    row, column, tuple_length = get_data_dims(data, T)
    if isnothing(column)
        t_data = Array{Tuple{Float64, Float64}}(undef, row)
        for r in 1:row
            t_data[r] = tuple(data[r, 1:tuple_length]...)
        end
    else
        t_data = Array{Tuple{Float64, Float64}}(undef, row, column)
        for r in 1:row, c in 1:column
            t_data[r, c] = tuple(data[r, c, 1:tuple_length]...)
        end
    end
    return _quadratic_from_tuple.(t_data)
end

function retransform_hdf_array(data::Array, T::Type{PiecewiseLinearPointData})
    row, column, tuple_length, array_length = get_data_dims(data, T)
    if isnothing(column)
        t_data = Array{Vector{Tuple{Float64, Float64}}}(undef, row)
        for r in 1:row
            tuple_array = Array{Tuple{Float64, Float64}}(undef, array_length)
            for l in 1:array_length
                tuple_array[l] = tuple(data[r, 1:tuple_length, l]...)
            end
            t_data[r] = tuple_array
        end
    else
        t_data = Array{Vector{Tuple{Float64, Float64}}}(undef, row, column)
        for r in 1:row, c in 1:column
            tuple_array = Array{Tuple{Float64, Float64}}(undef, array_length)
            for l in 1:array_length
                tuple_array[l] = tuple(data[r, c, 1:tuple_length, l]...)
            end
            t_data[r, c] = tuple_array
        end
    end
    return PiecewiseLinearPointData.(t_data)
end

function get_data_dims(data::Array, ::Type{QuadraticFunctionData})
    if length(size(data)) == 2
        row, tuple_length = size(data)
        return (row, nothing, tuple_length)
    elseif length(size(data)) == 3
        return size(data)
    else
        error("Hdf data array is $(length(size(data)))-D array, expected 2-D or 3-D array.")
    end
end

function get_data_dims(data::Array, ::Type{PiecewiseLinearPointData})
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
    metadata::TimeSeriesMetadata,
    rows::UnitRange,
    columns::UnitRange,
) where {T <: Probabilistic}
    _deserialize_time_series(T, storage, metadata, rows, columns, storage.file)
end

function _deserialize_time_series(
    ::Type{T},
    storage::Hdf5TimeSeriesStorage,
    metadata::TimeSeriesMetadata,
    rows::UnitRange,
    columns::UnitRange,
    ::Nothing,
) where {T <: Probabilistic}
    return HDF5.h5open(storage.file_path, "r") do file
        _deserialize_time_series(T, storage, metadata, rows, columns, file)
    end
end

function _deserialize_time_series(
    ::Type{T},
    storage::Hdf5TimeSeriesStorage,
    metadata::TimeSeriesMetadata,
    rows::UnitRange,
    columns::UnitRange,
    file::HDF5.File,
) where {T <: Probabilistic}
    # Note that all range checks must occur at a higher level.
    total_percentiles = length(get_percentiles(metadata))
    root = _get_root(storage, file)
    uuid = get_time_series_uuid(metadata)
    path = _get_time_series_path(root, uuid)
    attributes = _read_time_series_attributes(path)
    @assert_op length(attributes["dataset_size"]) == 3
    @debug "deserializing a Forecast" _group = LOG_GROUP_TIME_SERIES T
    data = SortedDict{Dates.DateTime, Matrix{attributes["data_type"]}}()
    initial_timestamp = get_initial_timestamp(metadata)
    interval = get_interval(metadata)
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
            range(start_time; length = length(columns), step = interval),
        )
            data[it] = @view data_read[i, 1:length(rows), 1:total_percentiles]
        end
    end

    return T(metadata, data)
end

function deserialize_time_series(
    ::Type{T},
    storage::Hdf5TimeSeriesStorage,
    metadata::TimeSeriesMetadata,
    rows::UnitRange,
    columns::UnitRange,
) where {T <: Scenarios}
    _deserialize_time_series(T, storage, metadata, rows, columns, storage.file)
end

function _deserialize_time_series(
    ::Type{T},
    storage::Hdf5TimeSeriesStorage,
    metadata::TimeSeriesMetadata,
    rows::UnitRange,
    columns::UnitRange,
    ::Nothing,
) where {T <: Scenarios}
    return HDF5.h5open(storage.file_path, "r") do file
        _deserialize_time_series(T, storage, metadata, rows, columns, file)
    end
end

function _deserialize_time_series(
    ::Type{T},
    storage::Hdf5TimeSeriesStorage,
    metadata::TimeSeriesMetadata,
    rows::UnitRange,
    columns::UnitRange,
    file::HDF5.File,
) where {T <: Scenarios}
    # Note that all range checks must occur at a higher level.
    total_scenarios = get_scenario_count(metadata)

    root = _get_root(storage, file)
    uuid = get_time_series_uuid(metadata)
    path = _get_time_series_path(root, uuid)
    attributes = _read_time_series_attributes(path)
    @assert_op attributes["type"] == T
    @assert_op length(attributes["dataset_size"]) == 3
    @debug "deserializing a Forecast" _group = LOG_GROUP_TIME_SERIES T
    data = SortedDict{Dates.DateTime, Matrix{attributes["data_type"]}}()
    initial_timestamp = get_initial_timestamp(metadata)
    interval = get_interval(metadata)
    start_time = initial_timestamp + interval * (first(columns) - 1)
    if length(columns) == 1
        data[start_time] =
            transpose(path["data"][1:total_scenarios, rows, first(columns)])
    else
        data_read =
            PermutedDimsArray(path["data"][1:total_scenarios, rows, columns], [3, 2, 1])
        for (i, it) in enumerate(
            range(start_time; length = length(columns), step = interval),
        )
            data[it] = @view data_read[i, 1:length(rows), 1:total_scenarios]
        end
    end

    return T(metadata, data)
end

function clear_time_series!(storage::Hdf5TimeSeriesStorage)
    # Re-create the file. HDF5 will not actually free up the deleted space until h5repack
    # is run on the file.
    _make_file(storage)
    @info "Cleared all time series."
end

get_num_time_series(storage::Hdf5TimeSeriesStorage) =
    _get_num_time_series(storage, storage.file)

function _get_num_time_series(storage::Hdf5TimeSeriesStorage, ::Nothing)
    HDF5.h5open(storage.file_path, "r") do file
        _get_num_time_series(storage, file)
    end
end

_get_num_time_series(storage::Hdf5TimeSeriesStorage, file::HDF5.File) =
    length(_get_root(storage, file))

_make_file(storage::Hdf5TimeSeriesStorage) = _make_file(storage, storage.file)

function _make_file(storage::Hdf5TimeSeriesStorage, ::Nothing)
    HDF5.h5open(storage.file_path, "w") do file
        _make_file(storage, file)
    end
end

function _make_file(storage::Hdf5TimeSeriesStorage, file::HDF5.File)
    root = HDF5.create_group(file, HDF5_TS_ROOT_PATH)
    HDF5.attributes(root)[TIME_SERIES_VERSION_KEY] = TIME_SERIES_DATA_FORMAT_VERSION
    _serialize_compression_settings(storage, root)
    return
end

function _serialize_compression_settings(storage::Hdf5TimeSeriesStorage, root)
    HDF5.attributes(root)["compression_enabled"] = storage.compression.enabled
    HDF5.attributes(root)["compression_type"] = string(storage.compression.type)
    HDF5.attributes(root)["compression_level"] = storage.compression.level
    HDF5.attributes(root)["compression_shuffle"] = storage.compression.shuffle
    return
end

function _deserialize_compression_settings!(storage::Hdf5TimeSeriesStorage)
    _deserialize_compression_settings!(storage, storage.file)
end

function _deserialize_compression_settings!(storage::Hdf5TimeSeriesStorage, ::Nothing)
    HDF5.h5open(storage.file_path, "r+") do file
        _deserialize_compression_settings!(storage, file)
    end
end

function _deserialize_compression_settings!(storage::Hdf5TimeSeriesStorage, file::HDF5.File)
    root = _get_root(storage, file)
    storage.compression = CompressionSettings(;
        enabled = HDF5.read(HDF5.attributes(root)["compression_enabled"]),
        type = CompressionTypes(HDF5.read(HDF5.attributes(root)["compression_type"])),
        level = HDF5.read(HDF5.attributes(root)["compression_level"]),
        shuffle = HDF5.read(HDF5.attributes(root)["compression_shuffle"]),
    )
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

function compare_values(
    x::Hdf5TimeSeriesStorage,
    y::Hdf5TimeSeriesStorage;
    compare_uuids = false,
    kwargs...,
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

    for ((uuid_x, data_x), (uuid_y, data_y)) in zip(item_x, item_y)
        if uuid_x != uuid_y
            @error "UUIDs don't match" uuid_x uuid_y
            return false
        end
        if data_x != data_y
            @error "data doesn't match" data_x data_y
            return false
        end
    end

    return true
end
