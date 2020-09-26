
import HDF5

const HDF5_TS_ROOT_PATH = "time_series"

"""
Stores all time series data in an HDF5 file.

The file used is assumed to be temporary and will be automatically deleted when there are
no more references to the storage object.
"""
mutable struct Hdf5TimeSeriesStorage <: TimeSeriesStorage
    file_path::String
    read_only::Bool
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
)
    if create_file
        if isnothing(filename)
            if isnothing(directory)
                directory = tempdir()
            end
            filename, io = mktemp(directory)
            close(io)
        end

        storage = Hdf5TimeSeriesStorage(filename, read_only)
        _make_file(storage)
    else
        storage = Hdf5TimeSeriesStorage(filename, read_only)
    end

    @debug "Constructed new Hdf5TimeSeriesStorage" storage.file_path read_only

    return storage
end

"""
Constructs Hdf5TimeSeriesStorage from an existing file.
"""
function from_file(
    ::Type{Hdf5TimeSeriesStorage},
    filename::AbstractString;
    read_only = false,
)
    if !isfile(filename)
        error("time series storage $filename does not exist")
    end

    if read_only
        file_path = abspath(filename)
    else
        file_path, io = mktemp()
        close(io)
        cp(filename, file_path; force = true)
    end
    storage = Hdf5TimeSeriesStorage(false; filename = file_path, read_only = read_only)
    @info "Loaded time series from storage file existing=$filename new=$(storage.file_path)"
    return storage
end

get_file_path(storage::Hdf5TimeSeriesStorage) = storage.file_path

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
        if !HDF5.exists(root, uuid)
            HDF5.g_create(root, uuid)
            path = root[uuid]
            data = get_array_for_hdf(ts)
            path["data"] = data
            _write_time_series_attributes!(storage, ts, path)
            path["components"] = [component_name]
            @debug "Create new time series entry." uuid component_uuid name initial_time
        else
            path = root[uuid]
            @debug "Add reference to existing time series entry." uuid component_uuid name
            _append_item!(path, "components", component_name)
        end
    end
end

function _write_time_series_attributes!(
    storage::Hdf5TimeSeriesStorage,
    ts::T,
    path,
) where {T <: StaticTimeSeries}
    _write_time_series_attributes_common!(storage, ts, path)
end

function _write_time_series_attributes!(
    storage::Hdf5TimeSeriesStorage,
    ts::T,
    path,
) where {T <: Forecast}
    _write_time_series_attributes_common!(storage, ts, path)
    interval = get_interval(ts)
    HDF5.attrs(path)["interval"] = time_period_conversion(interval).value
end

function _write_time_series_attributes_common!(storage::Hdf5TimeSeriesStorage, ts, path)
    initial_timestamp = Dates.datetime2epochms(get_initial_timestamp(ts))
    resolution = get_resolution(ts)
    HDF5.attrs(path)["initial_timestamp"] = initial_timestamp
    HDF5.attrs(path)["resolution"] = time_period_conversion(resolution).value
end

function _read_time_series_attributes(
    storage::Hdf5TimeSeriesStorage,
    path,
    row_index,
    num_rows,
    ::Type{T},
) where {T <: StaticTimeSeries}
    return _read_time_series_attributes_common(storage, path, row_index, num_rows)
end

function _read_time_series_attributes(
    storage::Hdf5TimeSeriesStorage,
    path,
    row_index,
    num_rows,
    ::Type{T},
) where {T <: Forecast}
    data = _read_time_series_attributes_common(storage, path, row_index, num_rows)
    data["interval"] = Dates.Millisecond(HDF5.read(HDF5.attrs(path)["interval"]))
    return data
end

function _read_time_series_attributes_common(storage::Hdf5TimeSeriesStorage, path, row_index, num_rows)
    initial_timestamp = Dates.epochms2datetime(
        HDF5.read(HDF5.attrs(path)["initial_timestamp"]),
    )
    resolution = Dates.Millisecond(HDF5.read(HDF5.attrs(path)["resolution"]))
    return Dict(
        "initial_timestamp" => initial_timestamp,
        "resolution" => resolution,
        "dataset_size" => size(path["data"]),
        "start_time" => initial_timestamp + resolution * (row_index - 1),
        "end_index" => row_index + num_rows - 1,
    )
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
        path = root[uuid]
        _append_item!(path, "components", component_name)
        @debug "Add reference to existing time series entry." uuid component_uuid name
    end
end

# TODO DT: broken
#function iterate_time_series(storage::Hdf5TimeSeriesStorage)
#    Channel() do channel
#        HDF5.h5open(storage.file_path, "r") do file
#            root = _get_root(storage, file)
#            for uuid_group in root
#                uuid_path = HDF5.name(uuid_group)
#                range = findlast("/", uuid_path)
#                uuid_str = uuid_path[(range.start + 1):end]
#                uuid = UUIDs.UUID(uuid_str)
#                internal = InfrastructureSystemsInternal(uuid)
#                ts = TimeDataContainer(get_time_series(storage, uuid), internal)
#                for item in HDF5.read(uuid_group["components"])
#                    component, name = deserialize_component_name(item)
#                    put!(channel, (component, name, ta))
#                end
#            end
#        end
#    end
#end

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
        if _remove_item!(path, "components", make_component_name(component_uuid, name))
            @debug "$path has no more references; delete it."
            HDF5.o_delete(path)
        end
    end
end

function deserialize_time_series(
    ::Type{T},
    storage::Hdf5TimeSeriesStorage,
    ts_metadata::TimeSeriesMetadata,
    row_index::Int,
    column_index::Int,
    num_rows::Int,
    num_columns::Int,
) where {T<:StaticTimeSeries}
    # Note that all range checks must occur at a higher level.
    return HDF5.h5open(storage.file_path, "r") do file
        root = _get_root(storage, file)
        uuid = get_time_series_uuid(ts_metadata)
        path = _get_time_series_path(root, uuid)
        attributes = _read_time_series_attributes(storage, path, row_index, num_rows, T)

        @assert length(attributes["dataset_size"]) == 1
        @debug "deserializing a StaticTimeSeries" T
        data = path["data"][row_index:attributes["end_index"]]
        return T(
            ts_metadata,
            TimeSeries.TimeArray(
                range(
                    attributes["start_time"];
                    length = num_rows,
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
    row_index::Int,
    column_index::Int,
    num_rows::Int,
    num_columns::Int,
) where {T <: Forecast}
    # Note that all range checks must occur at a higher level.
    total_rows = length(ts_metadata)
    total_columns = get_count(ts_metadata)
    use_same_uuid = num_rows == total_rows && num_columns == total_columns

    return HDF5.h5open(storage.file_path, "r") do file
        root = _get_root(storage, file)
        uuid = get_time_series_uuid(ts_metadata)
        path = _get_time_series_path(root, uuid)
        attributes = _read_time_series_attributes(storage, path, row_index, num_rows, T)

        @assert length(attributes["dataset_size"]) == 2
        @debug "deserializing a Forecast" T
        end_row_index = row_index + num_rows - 1
        data = SortedDict{Dates.DateTime, Array}()
        start_time = attributes["start_time"]
        if num_columns == 1
            data[start_time] = path["data"][row_index:end_row_index, column_index]
        else
            data_read =
                path["data"][row_index:end_row_index, column_index:(column_index + num_columns - 1)]
            for (i, it) in enumerate(range(attributes["start_time"]; length = num_columns, step = attributes["interval"]))
                data[it] = @view data_read[1:num_rows, i]
            end
        end

        new_ts = T(ts_metadata, data, use_same_uuid)
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

function _make_file(storage::Hdf5TimeSeriesStorage)
    HDF5.h5open(storage.file_path, "w") do file
        HDF5.g_create(file, HDF5_TS_ROOT_PATH)
    end
end

_get_root(storage::Hdf5TimeSeriesStorage, file) = file[HDF5_TS_ROOT_PATH]

function _get_time_series_path(root::HDF5.HDF5Group, uuid::UUIDs.UUID)
    uuid_str = string(uuid)
    if !HDF5.exists(root, uuid_str)
        throw(ArgumentError("UUID $uuid_str does not exist"))
    end

    return root[uuid_str]
end

function _append_item!(path::HDF5.HDF5Group, name::AbstractString, value::AbstractString)
    handle = HDF5.o_open(path, name)
    values = HDF5.read(handle)
    HDF5.close(handle)
    push!(values, value)

    ret = HDF5.o_delete(path, name)
    @assert ret == 0

    path[name] = values
    @debug "Appended $value to $name" values
end

"""
Removes value from the dataset called name.
Returns true if the array is empty afterwards.
"""
function _remove_item!(path::HDF5.HDF5Group, name::AbstractString, value::AbstractString)
    handle = HDF5.o_open(path, name)
    values = HDF5.read(handle)
    HDF5.close(handle)

    orig_len = length(values)
    filter!(x -> x != value, values)
    if length(values) != orig_len - 1
        throw(ArgumentError("$value wasn't stored in $name"))
    end

    ret = HDF5.o_delete(path, name)
    @assert ret == 0

    if isempty(values)
        is_empty = true
    else
        path[name] = values
        is_empty = false
    end
    @debug "Removed $value from $name" values

    return is_empty
end

function check_read_only(storage::Hdf5TimeSeriesStorage)
    if storage.read_only
        error("Operation not permitted; this time series file is read-only")
    end
end

function compare_values(x::Hdf5TimeSeriesStorage, y::Hdf5TimeSeriesStorage)::Bool
    data_x = sort!(collect(iterate_time_series(x)), by = z -> z[1])
    data_y = sort!(collect(iterate_time_series(y)), by = z -> z[1])
    if length(data_x) != length(data_y)
        @error "lengths don't match" length(data_x) length(data_y)
        return false
    end

    for ((uuid_x, name_x, ts_x), (uuid_y, name_y, ts_y)) in zip(data_x, data_y)
        if uuid_x != uuid_y
            @error "component UUIDs don't match" uuid_x uuid_y
            return false
        end
        if name_x != name_y
            @error "names don't match" name_x name_y
            return false
        end
        if TimeSeries.timestamp(ts_x.data) != TimeSeries.timestamp(ts_y.data)
            @error "timestamps don't match" ts_x.data ts_y.data
            return false
        end
        if TimeSeries.values(ts_x.data) != TimeSeries.values(ts_y.data)
            @error "values don't match" ts_x.data ts_y.data
            return false
        end
    end

    return true
end
