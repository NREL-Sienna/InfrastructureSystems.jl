
import HDF5

const HDF5_TS_ROOT_PATH = "time_series"

"""
Stores all time series data in an HDF5 file.
"""
struct Hdf5TimeSeriesStorage <: TimeSeriesStorage
    file_path::String
end

"""
Constructs Hdf5TimeSeriesStorage by creating a new file.
"""
function Hdf5TimeSeriesStorage(; filename=nothing)
    file_path = isnothing(filename) ? tempname() * ".h5" : filename
    storage = Hdf5TimeSeriesStorage(file_path)
    _make_file(storage)
    @debug "Created time series storage file." storage.file_path
    return storage
end

"""
Constructs Hdf5TimeSeriesStorage from an existing file.
"""
function from_file(::Type{Hdf5TimeSeriesStorage}, filename::AbstractString)
    file_path = tempname() * ".h5"
    cp(filename, file_path; force=true)
    storage = Hdf5TimeSeriesStorage(file_path)
    @info "Loaded time series from storage file existing=$filename new=$(storage.file_path)"
    return storage
end

get_file_path(storage::Hdf5TimeSeriesStorage) = storage.file_path

function add_time_series!(
                          storage::Hdf5TimeSeriesStorage,
                          component_uuid::UUIDs.UUID,
                          label::AbstractString,
                          ts::TimeSeriesData,
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
        else
            path = root[uuid]
            @debug "Add reference to existing time series entry." uuid component_uuid label
            _append_item!(path, "components", component_label)
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
                         index=0,
                         len=0,
                        )::TimeSeries.TimeArray
    return HDF5.h5open(storage.file_path, "r") do file
        root = _get_root(storage, file)
        path = _get_time_series_path(root, uuid)
        data = HDF5.read(path["data"])
        timestamps = HDF5.read(path["timestamps"])
        if index != 0
            # PERF: HDF5 allows reading a subset of a dataset. Implementing it would improve
            # performance, especially if the length of the time array is huge. As of now
            # the time arrays are at most 1-year, 5-minute resolution -> 105,120 entries
            # which consumes 821 KiB. Need to profile the latency of reads.
            # OS buffering may obviate the need to do this.
            @assert len != 0
            end_index = index + len - 1
            data = data[index:end_index]
            timestamps = timestamps[index:end_index]
        end

        # Note: we don't care what column names get returned. TimeArray creates :A, :B, ...
        return TimeSeries.TimeArray([Dates.epochms2datetime(x) for x in timestamps], data)
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
    # TODO: ignore the file_path variable but iterate through all data and compare
    return true
end
