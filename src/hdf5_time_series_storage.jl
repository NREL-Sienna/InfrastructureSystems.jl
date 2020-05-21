
import HDF5

const HDF5_TS_ROOT_PATH = "time_series"

"""
Stores all time series data in an HDF5 file.

The file used is assumed to be temporary and will be automatically deleted when there are
no more references to the storage object.
"""
mutable struct Hdf5TimeSeriesStorage <: TimeSeriesStorage
    file_path::String
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
"""
function Hdf5TimeSeriesStorage(create_file::Bool; filename = nothing, directory = nothing)
    if create_file
        if isnothing(filename)
            if isnothing(directory)
                directory = tempdir()
            end
            filename, io = mktemp(directory)
            close(io)
        end

        storage = Hdf5TimeSeriesStorage(filename)
        _make_file(storage)
    else
        storage = Hdf5TimeSeriesStorage(filename)
    end

    @debug "Constructed new Hdf5TimeSeriesStorage" storage.file_path

    return storage
end

function _cleanup(storage::Hdf5TimeSeriesStorage)
    if isfile(storage.file_path)
        @debug "Delete Hdf5TimeSeriesStorage" storage.file_path
        rm(storage.file_path)
    end
end

"""
Constructs Hdf5TimeSeriesStorage from an existing file.
"""
function from_file(::Type{Hdf5TimeSeriesStorage}, filename::AbstractString)
    file_path, io = mktemp()
    close(io)
    if !isfile(filename)
        error("time series storage $filename does not exist")
    end
    cp(filename, file_path; force = true)
    storage = Hdf5TimeSeriesStorage(false; filename = file_path)
    @info "Loaded time series from storage file existing=$filename new=$(storage.file_path)"
    return storage
end

get_file_path(storage::Hdf5TimeSeriesStorage) = storage.file_path

function add_time_series!(
    storage::Hdf5TimeSeriesStorage,
    component_uuid::UUIDs.UUID,
    label::AbstractString,
    ts::TimeSeriesData,
    columns = nothing,
)
    uuid = string(get_uuid(ts))
    component_label = make_component_label(component_uuid, label)

    HDF5.h5open(storage.file_path, "r+") do file
        root = _get_root(storage, file)
        if !HDF5.exists(root, uuid)
            HDF5.g_create(root, uuid)
            path = root[uuid]
            @debug "Create new time series entry." uuid component_uuid label
            path["data"] = TimeSeries.values(ts.data)
            timestamps = [Dates.datetime2epochms(x) for x in TimeSeries.timestamp(ts.data)]
            path["timestamps"] = timestamps
            # Storing the UUID as an integer would take less space, but HDF5 library says
            # arrays of 128-bit integers aren't supported.
            path["components"] = [component_label]
            if !isnothing(columns)
                HDF5.attrs(path)["columns"] = string.(columns)
            end
        else
            path = root[uuid]
            @debug "Add reference to existing time series entry." uuid component_uuid label
            _append_item!(path, "components", component_label)
            if !isnothing(columns)
                if !HDF5.exists(HDF5.attrs(path), "columns")
                    throw(ArgumentError("columns are specified but existing array does not have columns"))
                end
                existing = HDF5.attrs(path)["columns"]
                if columns != existing
                    throw(ArgumentError("columns do not match $columns $existing"))
                end
            end
        end
    end
end

function iterate_time_series(storage::Hdf5TimeSeriesStorage)
    Channel() do channel
        HDF5.h5open(storage.file_path, "r") do file
            root = _get_root(storage, file)
            for uuid_group in root
                uuid_path = HDF5.name(uuid_group)
                range = findlast("/", uuid_path)
                uuid_str = uuid_path[(range.start + 1):end]
                uuid = UUIDs.UUID(uuid_str)
                internal = InfrastructureSystemsInternal(uuid)
                time_series = TimeSeriesData(get_time_series(storage, uuid), internal)
                for item in HDF5.read(uuid_group["components"])
                    component, label = deserialize_component_label(item)
                    put!(channel, (component, label, time_series))
                end
            end
        end
    end
end

function remove_time_series!(
    storage::Hdf5TimeSeriesStorage,
    uuid::UUIDs.UUID,
    component_uuid::UUIDs.UUID,
    label::AbstractString,
)
    HDF5.h5open(storage.file_path, "r+") do file
        root = _get_root(storage, file)
        path = _get_time_series_path(root, uuid)
        if _remove_item!(path, "components", make_component_label(component_uuid, label))
            @debug "$path has no more references; delete it."
            HDF5.o_delete(path)
        end
    end
end

function get_time_series(
    storage::Hdf5TimeSeriesStorage,
    uuid::UUIDs.UUID;
    index = 0,
    len = 0,
)::TimeSeries.TimeArray
    return HDF5.h5open(storage.file_path, "r") do file
        root = _get_root(storage, file)
        path = _get_time_series_path(root, uuid)

        if index == 0
            data = HDF5.read(path["data"])
            timestamps = HDF5.read(path["timestamps"])
        else
            @assert len != 0
            end_index = index + len - 1
            # HDF5.readmmap could be faster in many cases than this. However, experiments
            # resulted in various crashes if we tried to close the file before references
            # to the array data were garbage collected. May need to consult with the
            # Julia HDF5 library maintainers about that.
            data = path["data"][index:end_index]
            timestamps = path["timestamps"][index:end_index]
        end

        # If the user set column names, return them. Otherwise, let TimeArray pick them.
        dtimestamps = [Dates.epochms2datetime(x) for x in timestamps]
        if HDF5.exists(HDF5.attrs(path), "columns")
            columns = Symbol.(HDF5.read(HDF5.attrs(path)["columns"]))
            return TimeSeries.TimeArray(dtimestamps, data, columns)
        end

        return TimeSeries.TimeArray(dtimestamps, data)
    end
end

function clear_time_series!(storage::Hdf5TimeSeriesStorage)
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

function compare_values(x::Hdf5TimeSeriesStorage, y::Hdf5TimeSeriesStorage)::Bool
    data_x = sort!(collect(iterate_time_series(x)), by = z -> z[1])
    data_y = sort!(collect(iterate_time_series(y)), by = z -> z[1])
    if length(data_x) != length(data_y)
        @error "lengths don't match" length(data_x) length(data_y)
        return false
    end

    for ((uuid_x, label_x, ts_x), (uuid_y, label_y, ts_y)) in zip(data_x, data_y)
        if uuid_x != uuid_y
            @error "component UUIDs don't match" uuid_x uuid_y
            return false
        end
        if label_x != label_y
            @error "labels don't match" label_x label_y
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
