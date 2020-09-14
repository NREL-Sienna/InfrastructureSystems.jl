
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
- `::Type{T}`: time_seriesed component type; may be abstract
- `data::SystemData`: system
- `metadata_file::AbstractString`: metadata file for time series
  that includes an array of TimeSeriesFileMetadata instances or a vector.
- `resolution::DateTime.Period=nothing`: skip time_series that don't match this resolution.
"""
function add_time_series!(
    ::Type{T},
    data::SystemData,
    metadata_file::AbstractString;
    resolution = nothing,
) where {T <: InfrastructureSystemsComponent}
    metadata = read_time_series_file_metadata(metadata_file)
    return add_time_series!(T, data, metadata; resolution = resolution)
end

"""
Adds time_series from a metadata file or metadata descriptors.

# Arguments
- `data::SystemData`: system
- `file_metadata::Vector{TimeSeriesFileMetadata}`: metadata for time series
- `resolution::DateTime.Period=nothing`: skip time_series that don't match this resolution.
"""
function add_time_series!(
    ::Type{T},
    data::SystemData,
    file_metadata::Vector{TimeSeriesFileMetadata};
    resolution = nothing,
) where {T <: InfrastructureSystemsComponent}
    cache = TimeSeriesCache()

    for metadata in file_metadata
        add_time_series!(T, data, cache, metadata; resolution = resolution)
    end
end

"""
Add a time_series.

# Arguments
- `data::SystemData`: infrastructure
- `time_series`: Any object of subtype time_series

Throws ArgumentError if the time_series's component is not stored in the system.

"""
function add_time_series!(
    data::SystemData,
    component::InfrastructureSystemsComponent,
    time_series::TimeSeriesData,
)
    ta = TimeArrayWrapper(get_data(time_series))
    ts_metadata = make_time_series_metadata(time_series, ta)
    add_time_series!(data, component, ts_metadata, ta)
end

function add_time_series!(
    data::SystemData,
    component::InfrastructureSystemsComponent,
    ts_metadata::T,
    ta::TimeArrayWrapper;
    skip_if_present = false,
) where {T <: TimeSeriesMetadata}
    _validate_component(data, component)
    check_add_time_series!(data.time_series_params, ts_metadata)
    check_read_only(data.time_series_storage)
    add_time_series!(component, ts_metadata, skip_if_present = skip_if_present)
    # TODO: can this be atomic with time_series addition?
    add_time_series!(
        data.time_series_storage,
        get_uuid(component),
        get_label(ts_metadata),
        ta,
        get_columns(T, ta.data),
    )
end

"""
Add a time_series from a CSV file.

See [`TimeSeriesFileMetadata`](@ref) for description of normalization_factor.
"""
function add_time_series!(
    data::SystemData,
    filename::AbstractString,
    component::InfrastructureSystemsComponent,
    label::AbstractString;
    normalization_factor::Union{String, Float64} = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
)
    component_name = get_name(component)
    ta = read_time_series(filename, component_name)
    ta_component = ta[Symbol(component_name)]
    _add_time_series!(
        data,
        component,
        label,
        ta_component,
        normalization_factor,
        scaling_factor_multiplier,
    )
end

"""
Add a time_series to a system from a TimeSeries.TimeArray.

See [`TimeSeriesFileMetadata`](@ref) for description of normalization_factor.
"""
function add_time_series!(
    data::SystemData,
    ta::TimeSeries.TimeArray,
    component::InfrastructureSystemsComponent,
    label::AbstractString;
    normalization_factor::Union{String, Float64} = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
)
    ta_component = ta[Symbol(get_name(component))]
    _add_time_series!(
        data,
        component,
        label,
        ta_component,
        normalization_factor,
        scaling_factor_multiplier,
    )
end

"""
Add a time_series to a system from a DataFrames.DataFrame.

See [`TimeSeriesFileMetadata`](@ref) for description of normalization_factor.
"""
function add_time_series!(
    data::SystemData,
    df::DataFrames.DataFrame,
    component::InfrastructureSystemsComponent,
    label::AbstractString;
    normalization_factor::Union{String, Float64} = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
    timestamp = :timestamp,
)
    ta = TimeSeries.TimeArray(df; timestamp = timestamp)
    add_time_series!(
        data,
        ta,
        component,
        label;
        normalization_factor = normalization_factor,
        scaling_factor_multiplier = scaling_factor_multiplier,
    )
end

function add_time_series!(
    ::Type{T},
    data::SystemData,
    cache::TimeSeriesCache,
    file_metadata::TimeSeriesFileMetadata;
    resolution = nothing,
) where {T <: InfrastructureSystemsComponent}
    set_component!(file_metadata, data, InfrastructureSystems)
    component = file_metadata.component

    ts_metadata, ta = make_time_series!(cache, file_metadata; resolution = resolution)
    if !isnothing(ts_metadata)
        add_time_series!(data, component, ts_metadata, ta)
    end
end

"""
Remove the time series data for a component.
"""
function remove_time_series!(
    ::Type{T},
    data::SystemData,
    component::InfrastructureSystemsComponent,
    initial_time::Dates.DateTime,
    label::String,
) where {T <: TimeSeriesData}
    type = time_series_data_to_metadata(T)
    time_series = get_time_series(type, component, initial_time, label)
    uuid = get_time_series_uuid(time_series)
    # TODO: can this be atomic?
    remove_time_series_metadata!(type, component, initial_time, label)
    remove_time_series!(data.time_series_storage, uuid, get_uuid(component), label)
end

"""
Return a vector of time_series from TimeSeriesFileMetadata.

# Arguments
- `cache::TimeSeriesCache`: cached data
- `ts_file_metadata::TimeSeriesFileMetadata`: metadata
- `resolution::{Nothing, Dates.Period}`: skip any time_series that don't match this resolution
"""
function make_time_series!(
    cache::TimeSeriesCache,
    ts_file_metadata::TimeSeriesFileMetadata;
    resolution = nothing,
)
    info = add_time_series_info!(cache, ts_file_metadata)
    return _make_time_series(info, resolution)
end

function _add_time_series!(
    data::SystemData,
    component::InfrastructureSystemsComponent,
    label::AbstractString,
    time_series::TimeSeries.TimeArray,
    normalization_factor,
    scaling_factor_multiplier,
)
    time_series = handle_scaling_factor(time_series, normalization_factor)
    # TODO: This code path needs to accept a metdata file or parameters telling it which
    # type of time_series to create.
    ta = TimeArrayWrapper(time_series)
    ts_metadata = DeterministicMetadata(label, ta, scaling_factor_multiplier)
    add_time_series!(data, component, ts_metadata, ta)
end

function _make_time_series(cache::TimeSeriesCache, resolution)
    time_series_arrays = Vector{TimeSeriesData}()

    for info in cache.infos
        time_series = _make_time_series(info, resolution)
        if !isnothing(time_series)
            push!(time_series_arrays, time_series)
        end
    end

    return time_series_arrays
end

function _make_time_series(info::TimeSeriesParsedInfo, resolution)
    len = length(info.data)
    @assert len >= 2
    timestamps = TimeSeries.timestamp(info.data)
    res = timestamps[2] - timestamps[1]
    if !isnothing(resolution) && res != resolution
        @debug "Skip time_series with resolution=$res; doesn't match user=$resolution"
        return nothing, nothing
    end

    ta = info.data[Symbol(get_name(info.component))]
    ta = handle_scaling_factor(ta, info.normalization_factor)
    ta_wrapper = TimeArrayWrapper(ta)
    ts_metadata =
        info.time_series_type(info.label, ta_wrapper, info.scaling_factor_multiplier)
    @debug "Created $ts_metadata"
    return ts_metadata, ta_wrapper
end

function add_time_series_info!(cache::TimeSeriesCache, metadata::TimeSeriesFileMetadata)
    time_series = _add_time_series_info!(cache, metadata.data_file, metadata.component_name)
    info = TimeSeriesParsedInfo(metadata, time_series)
    @debug "Added TimeSeriesParsedInfo" metadata
    return info
end

"""
Return true if time_series are stored contiguously.

Throws ArgumentError if there are no time_series stored.
"""
function are_time_series_contiguous(data::SystemData)
    for component in iterate_components_with_time_series(data.components)
        if has_time_series(component)
            return are_time_series_contiguous(component)
        end
    end

    throw(ArgumentError("no time_series are stored"))
end

"""
Generates all possible initial times for the stored time_series. This should return the same
result regardless of whether the time_series have been stored as one contiguous array or
chunks of contiguous arrays, such as one 365-day time_series vs 365 one-day time_series.

Throws ArgumentError if there are no time_series stored, interval is not a multiple of the
system's time_series resolution, or if the stored time_series have overlapping timestamps.

# Arguments
- `data::SystemData`: system
- `interval::Dates.Period`: Amount of time in between each initial time.
- `horizon::Int`: Length of each time_series array.
- `initial_time::Union{Nothing, Dates.DateTime}=nothing`: Start with this time. If nothing,
  use the first initial time.
"""
function generate_initial_times(
    data::SystemData,
    interval::Dates.Period,
    horizon::Int;
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
)
    for component in iterate_components_with_time_series(data.components)
        if has_time_series(component)
            return generate_initial_times(
                component,
                interval,
                horizon;
                initial_time = initial_time,
            )
        end
    end

    throw(ArgumentError("no time_series are stored"))
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
- `initial_time = nothing`: Only return time_series matching this value.
- `label = nothing`: Only return time_series matching this value.
"""
function get_time_series_multiple(
    data::SystemData,
    filter_func = nothing;
    type = nothing,
    initial_time = nothing,
    label = nothing,
)
    Channel() do channel
        for component in iterate_components_with_time_series(data.components)
            for time_series in get_time_series_multiple(
                component,
                filter_func;
                type = type,
                initial_time = initial_time,
                label = label,
            )
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
