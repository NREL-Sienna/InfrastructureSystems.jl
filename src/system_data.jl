
const TIME_SERIES_STORAGE_FILE = "time_series_storage.h5"
const VALIDATION_DESCRIPTOR_FILE = "validation_descriptors.json"

"""
    mutable struct SystemData <: InfrastructureSystemsType
        components::Components
        time_series_params::TimeSeriesParameters
        validation_descriptors::Vector
        time_series_storage::TimeSeriesStorage
        time_series_storage_file::Union{Nothing, String}
        internal::InfrastructureSystemsInternal
    end

Container for system components and time series data
"""
mutable struct SystemData <: InfrastructureSystemsType
    components::Components
    time_series_params::TimeSeriesParameters
    time_series_storage::TimeSeriesStorage
    validation_descriptors::Vector
    internal::InfrastructureSystemsInternal
end

"""
Construct SystemData to store components and time series data.

# Arguments
- `validation_descriptor_file = nothing`: Optionally, a file defining component validation
  descriptors.
- `time_series_in_memory = false`: Controls whether time series data is stored in memory or
  in a file.
- time_series_directory = nothing`: Controls what directory time series data is stored in.
  Default is tempdir().
"""
function SystemData(;
    validation_descriptor_file = nothing,
    time_series_in_memory = false,
    time_series_directory = nothing,
)
    if isnothing(validation_descriptor_file)
        validation_descriptors = Vector()
    else
        validation_descriptors = read_validation_descriptor(validation_descriptor_file)
    end

    ts_storage = make_time_series_storage(;
        in_memory = time_series_in_memory,
        directory = time_series_directory,
    )
    components = Components(ts_storage, validation_descriptors)
    return SystemData(
        components,
        TimeSeriesParameters(),
        ts_storage,
        validation_descriptors,
        InfrastructureSystemsInternal(),
    )
end

function SystemData(
    time_series_params,
    validation_descriptors,
    time_series_storage,
    internal,
)
    components = Components(time_series_storage, validation_descriptors)
    return SystemData(
        components,
        time_series_params,
        time_series_storage,
        validation_descriptors,
        internal,
    )
end

"""
Adds time_series from a metadata file or metadata descriptors.

# Arguments
- `data::SystemData`: system
- `::Type{T}`: type of the component associated with time series data; may be abstract
- `metadata_file::AbstractString`: metadata file for time series
  that includes an array of TimeSeriesFileMetadata instances or a vector.
- `resolution::DateTime.Period=nothing`: skip time_series that don't match this resolution.
"""
function add_time_series_from_file_metadata!(
    data::SystemData,
    ::Type{T},
    metadata_file::AbstractString;
    resolution = nothing,
) where {T <: InfrastructureSystemsComponent}
    metadata = read_time_series_file_metadata(metadata_file; resolution = resolution)
    return add_time_series_from_file_metadata!(data, T, metadata)
end

"""
Adds time series data from a metadata file or metadata descriptors.

# Arguments
- `data::SystemData`: system
- `file_metadata::Vector{TimeSeriesFileMetadata}`: metadata for time series
- `resolution::DateTime.Period=nothing`: skip time_series that don't match this resolution.
"""
function add_time_series_from_file_metadata!(
    data::SystemData,
    ::Type{T},
    file_metadata::Vector{TimeSeriesFileMetadata};
    resolution=nothing
) where {T <: InfrastructureSystemsComponent}
    cache = TimeSeriesCache()

    for metadata in file_metadata
        if resolution !== nothing && metadata.resolution != resolution
            _add_time_series_from_file_metadata!(data, T, cache, metadata)
        end
    end
    return
end

"""
Add time series data to a component.

# Arguments
- `data::SystemData`: SystemData
- `component::InfrastructureSystemsComponent`: will store the time series reference
- `time_series::TimeSeriesData`: Any object of subtype TimeSeriesData

Throws ArgumentError if the component is not stored in the system.

"""
function add_time_series!(
    data::SystemData,
    component::InfrastructureSystemsComponent,
    time_series::TimeSeriesData,
)
    metadata_type = time_series_data_to_metadata(typeof(time_series))
    ts_metadata = metadata_type(time_series)
    _add_time_series_metadata!(data, component, ts_metadata, time_series)
end

"""
Add the same time series data to multiple components.

# Arguments
- `data::SystemData`: SystemData
- `components`: iterable of components that will store the same time series reference
- `time_series::TimeSeriesData`: Any object of subtype TimeSeriesData

This is significantly more efficent than calling add_time_series! for each component
individually with the same data because in this case, only one time series array is stored.

Throws ArgumentError if a component is not stored in the system.
"""
function add_time_series!(data::SystemData, components, time_series::TimeSeriesData)
    metadata_type = time_series_data_to_metadata(typeof(time_series))
    ts_metadata = metadata_type(time_series)
    for component in components
        _add_time_series_metadata!(data, component, ts_metadata, time_series)
    end
end

function _add_time_series_metadata!(
    data::SystemData,
    component::InfrastructureSystemsComponent,
    ts_metadata::T,
    ts::TimeSeriesData;
    skip_if_present = false,
) where {T <: TimeSeriesMetadata}
    _validate_component(data, component)
    check_add_time_series!(data.time_series_params, ts)
    check_read_only(data.time_series_storage)
    add_time_series!(component, ts_metadata, skip_if_present = skip_if_present)
    # TODO: can this be atomic with time_series addition?
    add_time_series!(
        data.time_series_storage,
        get_uuid(component),
        get_name(ts_metadata),
        ts,
    )
end

function _add_time_series_from_file_metadata!(
    data::SystemData,
    ::Type{T},
    cache::TimeSeriesCache,
    file_metadata::TimeSeriesFileMetadata
) where {T <: InfrastructureSystemsComponent}
    set_component!(file_metadata, data, InfrastructureSystems)
    component = file_metadata.component

    time_series = make_time_series!(cache, file_metadata)
    if !isnothing(ts)
        add_time_series!(data, component, time_series)
    end
end

"""
Remove the time series data for a component.
"""
function remove_time_series!(
    ::Type{T},
    data::SystemData,
    component::InfrastructureSystemsComponent,
    name::String,
) where {T <: TimeSeriesData}
    type = time_series_data_to_metadata(T)
    time_series = get_time_series(type, component, name)
    uuid = get_time_series_uuid(time_series)
    # TODO: can this be atomic?
    remove_time_series_metadata!(type, component, name)
    remove_time_series!(data.time_series_storage, uuid, get_uuid(component), name)
end

"""
Return a time series from TimeSeriesFileMetadata.

# Arguments
- `cache::TimeSeriesCache`: cached data
- `ts_file_metadata::TimeSeriesFileMetadata`: metadata
- `resolution::{Nothing, Dates.Period}`: skip any time_series that don't match this resolution
"""
function make_time_series!(
    cache::TimeSeriesCache,
    ts_file_metadata::TimeSeriesFileMetadata,
)
    info = add_time_series_info!(cache, ts_file_metadata)
    return _make_time_series(info)
end

# TODO DT: probably not needed any longer
#function _add_time_series!(
#    data::SystemData,
#    component::InfrastructureSystemsComponent,
#    name::AbstractString,
#    time_series::TimeSeries.TimeArray,
#    normalization_factor,
#    scaling_factor_multiplier,
#)
#    time_series = handle_normalization_factor(time_series, normalization_factor)
#    # TODO: This code path needs to accept a metdata file or parameters telling it which
#    # type of time_series to create.
#    ts_metadata = DeterministicMetadata(name, time_series, scaling_factor_multiplier)
#    _add_time_series_metadata!(data, component, ts_metadata, time_series)
#end

function _make_time_array(info::TimeSeriesParsedInfo)
    series_length=length(info.data)
    timestamps = range(info.initial_time; length = series_length, step = resolution)
    return TimeSeries.TimeArray(timestamps, info.data.data[get_name(info.component)])
end


function _make_time_series(info::TimeSeriesParsedInfo)
    ta = info.data[Symbol(get_name(info.component))]
    if info.time_series_type <: SingleTimeSeries
        ts = info.time_series_type(name = info.name,
                                   data = _make_time_array(info.data),
                                   scaling_factot_multiplier = info.scaling_factor_multiplier,
                                   resolution = info.resolution,
                                   initial_timestamp = info.initial_time)
    else info.time_series_type <: Forecast
        ts = info.time_series_type(name = info.name,
                                   data = info.data.data,
                                   scaling_factot_multiplier = info.scaling_factor_multiplier,
                                   resolution = info.resolution,
                                   initial_timestamp = info.initial_time)
    end

    ts = handle_normalization_factor(ts, info.normalization_factor)
    @debug "Created $ts"
    return ts
end

function add_time_series_info!(cache::TimeSeriesCache, metadata::TimeSeriesFileMetadata)
    time_series = _add_time_series_info!(cache, metadata)
    info = TimeSeriesParsedInfo(metadata, time_series)
    @debug "Added TimeSeriesParsedInfo" metadata
    return info
end

"""
Checks that the component exists in data and the UUID's match.
"""
function _validate_component(
    data::SystemData,
    component::T,
) where {T <: InfrastructureSystemsComponent}
    comp = get_component(T, data.components, get_name(component))
    if isnothing(comp)
        throw(ArgumentError("no $T with name=$(get_name(component)) is stored"))
    end

    user_uuid = get_uuid(component)
    ps_uuid = get_uuid(comp)
    if user_uuid != ps_uuid
        throw(ArgumentError(
            "comp UUID doesn't match, perhaps it was copied?; " *
            "$T name=$(get_name(component)) user=$user_uuid system=$ps_uuid",
        ))
    end
end

function compare_values(x::SystemData, y::SystemData)::Bool
    match = true
    for name in fieldnames(SystemData)
        if name == :components
            # Not deserialized in IS.
            continue
        end
        if !compare_values(getfield(x, name), getfield(y, name))
            @error "SystemData field=$name does not match"
            match = false
        end
    end

    return match
end

function remove_component!(::Type{T}, data::SystemData, name) where {T}
    return remove_component!(T, data.components, name)
end

function remove_component!(data::SystemData, component)
    remove_component!(data.components, component)
end

function remove_components!(::Type{T}, data::SystemData) where {T}
    return remove_components!(T, data.components)
end

function clear_time_series!(data::SystemData)
    clear_time_series!(data.time_series_storage)
    clear_time_series!(data.components)
    reset_info!(data.time_series_params)
end

"""
Returns an iterator of TimeSeriesData instances attached to the system.

Note that passing a filter function can be much slower than the other filtering parameters
because it reads time series data from media.

Call `collect` on the result to get an array.

# Arguments
- `data::SystemData`: system
- `filter_func = nothing`: Only return time_series for which this returns true.
- `type = nothing`: Only return time_series with this type.
- `name = nothing`: Only return time_series matching this value.
"""
function get_time_series_multiple(
    data::SystemData,
    filter_func = nothing;
    type = nothing,
    name = nothing,
)
    Channel() do channel
        for component in iterate_components_with_time_series(data.components)
            for time_series in
                get_time_series_multiple(component, filter_func; type = type, name = name)
                put!(channel, time_series)
            end
        end
    end
end

"""
Return the time delta between the first two stored time_series.
if less than two are stored, return Dates.Second(0).
"""
function get_time_series_interval(data::SystemData)
    initial_times = get_time_series_initial_times(data)
    if length(initial_times) <= 1
        return Dates.Second(0)
    end

    return initial_times[2] - initial_times[1]
end

"""
Return a tuple of counts of components with time_series and total time_series.
"""
function get_time_series_counts(data::SystemData)
    component_count = 0
    time_series_count = 0
    for component in iterate_components_with_time_series(data.components)
        component_count += 1
        time_series_count += get_num_time_series(component)
    end

    return component_count, time_series_count
end

"""
Set the component value in metadata by looking up the category in module.
This requires that category be a string version of a component's abstract type.
Modules can override for custom behavior.
"""
function set_component!(metadata::TimeSeriesFileMetadata, data::SystemData, mod::Module)

    category = getfield(mod, Symbol(metadata.category))
    if isconcretetype(category)
        metadata.component =
            get_component(category, data.components, metadata.component_name)
        if isnothing(metadata.component)
            throw(DataFormatError("no component category=$category name=$(metadata.component_name)"))
        end
    else
        # Note: this could dispatch to higher-level modules that reimplement it.
        components = get_components_by_name(category, data, metadata.component_name)
        if length(components) == 0
            @warn "no component category=$category name=$(metadata.component_name)"
            metadata.component = nothing
        elseif length(components) == 1
            metadata.component = components[1]
        else
            throw(DataFormatError("duplicate names type=$(category) name=$(metadata.component_name)"))
        end
    end
end

"""
Parent object should call this prior to serialization so that SystemData can store the
appropriate path information for the time series data.
"""
function prepare_for_serialization!(
    data::SystemData,
    filename::AbstractString;
    force = false,
)
    directory = dirname(filename)
    if !isdir(directory)
        mkpath(directory)
    end

    files = [
        filename,
        joinpath(directory, TIME_SERIES_STORAGE_FILE),
        joinpath(directory, VALIDATION_DESCRIPTOR_FILE),
    ]
    for file in files
        if !force && isfile(file)
            error("$file already exists. Set force=true to overwrite.")
        end
    end

    ext = get_ext(data.internal)
    ext["serialization_directory"] = directory
    ext["basename"] = splitext(basename(filename))[1]
end

function serialize(data::SystemData)
    @debug "serialize SystemData"
    json_data = Dict()
    for field in (:components, :time_series_params, :internal)
        json_data[string(field)] = serialize(getfield(data, field))
    end

    ext = get_ext(data.internal)
    if !haskey(ext, "serialization_directory")
        error("prepare_for_serialization! was not called")
    end
    directory = pop!(ext, "serialization_directory")
    base = pop!(ext, "basename")
    isempty(ext) && clear_ext!(data.internal)

    time_series_base_name = base * "_" * TIME_SERIES_STORAGE_FILE
    time_series_storage_file = joinpath(directory, time_series_base_name)
    serialize(data.time_series_storage, time_series_storage_file)
    json_data["time_series_storage_file"] = time_series_base_name
    json_data["time_series_storage_type"] = string(typeof(data.time_series_storage))

    descriptor_base_name = base * "_" * VALIDATION_DESCRIPTOR_FILE
    descriptor_file = joinpath(directory, descriptor_base_name)
    descriptors = Dict("struct_validation_descriptors" => data.validation_descriptors)
    text = JSON3.write(descriptors)
    open(descriptor_file, "w") do io
        write(io, text)
    end
    json_data["validation_descriptor_file"] = descriptor_base_name
    return json_data
end

function deserialize(::Type{SystemData}, raw; time_series_read_only = false)
    @debug "deserialize" raw
    time_series_params = deserialize(TimeSeriesParameters, raw["time_series_params"])
    # The code calling this function must have changed to this directory.
    if !isfile(raw["time_series_storage_file"])
        error("time series file $(raw["time_series_storage_file"]) does not exist")
    end
    if !isfile(raw["validation_descriptor_file"])
        error("validation descriptor file $(raw["validation_descriptor_file"]) does not exist")
    end
    validation_descriptors = read_validation_descriptor(raw["validation_descriptor_file"])

    if strip_module_name(raw["time_series_storage_type"]) == "InMemoryTimeSeriesStorage"
        hdf5_storage = Hdf5TimeSeriesStorage(raw["time_series_storage_file"], true)
        time_series_storage = InMemoryTimeSeriesStorage(hdf5_storage)
    else
        time_series_storage = from_file(
            Hdf5TimeSeriesStorage,
            raw["time_series_storage_file"];
            read_only = time_series_read_only,
        )
    end

    internal = deserialize(InfrastructureSystemsInternal, raw["internal"])
    @debug "deserialize" validation_descriptors time_series_storage internal
    sys = SystemData(
        time_series_params,
        validation_descriptors,
        time_series_storage,
        internal,
    )
    # Note: components need to be deserialized by the parent so that they can got through
    # the proper checks.
    return sys
end

# Redirect functions to Components and TimeSeriesContainer

add_component!(data::SystemData, component; kwargs...) =
    add_component!(data.components, component; kwargs...)
iterate_components(data::SystemData) = iterate_components(data.components)

get_component(::Type{T}, data::SystemData, args...) where {T} =
    get_component(T, data.components, args...)

function get_component(data::SystemData, uuid::Base.UUID)
    for component in get_components(InfrastructureSystemsComponent, data)
        if get_uuid(component) == uuid
            return component
        end
    end

    @error "no component with UUID $uuid is stored"
    return nothing
end

function get_components(
    ::Type{T},
    data::SystemData,
    filter_func::Union{Nothing, Function} = nothing,
) where {T}
    return get_components(T, data.components, filter_func)
end

get_components_by_name(::Type{T}, data::SystemData, args...) where {T} =
    get_components_by_name(T, data.components, args...)

#get_component_time_series(::Type{T}, data::SystemData, args...) where T =
#    get_component_time_series(T, data.time_series, args...)
#get_time_series(::Type{T}, data::SystemData, component, args...) where T = get_time_series(
#    T, component, args...
#)
get_time_series_initial_times(data::SystemData) =
    get_time_series_initial_times(data.components)
get_time_series_initial_time(data::SystemData) =
    get_time_series_initial_time(data.components)
get_time_series_last_initial_time(data::SystemData) =
    get_time_series_last_initial_time(data.components)
get_time_series_horizon(data::SystemData) = get_time_series_horizon(data.time_series_params)
get_time_series_resolution(data::SystemData) =
    get_time_series_resolution(data.time_series_params)
clear_components!(data::SystemData) = clear_components!(data.components)
check_time_series_consistency(data::SystemData) =
    check_time_series_consistency(data.components)
validate_time_series_consistency(data::SystemData) =
    validate_time_series_consistency(data.components)
