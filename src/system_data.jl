
const TIME_SERIES_STORAGE_FILE = "time_series_storage.h5"
const TIME_SERIES_DIRECTORY_ENV_VAR = "SIIP_TIME_SERIES_DIRECTORY"
const VALIDATION_DESCRIPTOR_FILE = "validation_descriptors.json"

"""
    mutable struct SystemData <: InfrastructureSystemsType
        components::Components
        "Masked components are attached to the system for overall management purposes but
        are not exposed in the standard library calls like [`get_components`](@ref).
        Examples are components in a subsystem."
        masked_components::Components
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
    masked_components::Components
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
  - `time_series_directory = nothing`: Controls what directory time series data is stored in.
    Default is tempdir().
  - `compression = CompressionSettings()`: Controls compression of time series data.
"""
function SystemData(;
    validation_descriptor_file=nothing,
    time_series_in_memory=false,
    time_series_directory=nothing,
    compression=CompressionSettings(),
)
    if isnothing(validation_descriptor_file)
        validation_descriptors = Vector()
    else
        validation_descriptors = read_validation_descriptor(validation_descriptor_file)
    end

    if time_series_directory === nothing && haskey(ENV, TIME_SERIES_DIRECTORY_ENV_VAR)
        time_series_directory = ENV[TIME_SERIES_DIRECTORY_ENV_VAR]
    end

    ts_storage = make_time_series_storage(;
        in_memory=time_series_in_memory,
        directory=time_series_directory,
        compression=compression,
    )
    components = Components(ts_storage, validation_descriptors)
    masked_components = Components(ts_storage, validation_descriptors)
    return SystemData(
        components,
        masked_components,
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
    masked_components = Components(time_series_storage, validation_descriptors)
    return SystemData(
        components,
        masked_components,
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
    resolution=nothing,
) where {T <: InfrastructureSystemsComponent}
    metadata = read_time_series_file_metadata(metadata_file)
    return add_time_series_from_file_metadata!(data, T, metadata; resolution=resolution)
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
    resolution=nothing,
) where {T <: InfrastructureSystemsComponent}
    cache = TimeSeriesParsingCache()
    for metadata in file_metadata
        if resolution === nothing || metadata.resolution == resolution
            add_time_series_from_file_metadata_internal!(data, T, cache, metadata)
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
    time_series::TimeSeriesData;
    skip_if_present=false,
)
    metadata_type = time_series_data_to_metadata(typeof(time_series))
    ts_metadata = metadata_type(time_series)
    _attach_time_series_and_serialize!(
        data,
        component,
        ts_metadata,
        time_series;
        skip_if_present=skip_if_present,
    )
    return
end

"""
Add the same time series data to multiple components.

# Arguments

  - `data::SystemData`: SystemData
  - `components`: iterable of components that will store the same time series reference
  - `time_series::TimeSeriesData`: Any object of subtype TimeSeriesData

This is significantly more efficent than calling `add_time_series!` for each component
individually with the same data because in this case, only one time series array is stored.

Throws ArgumentError if a component is not stored in the system.
"""
function add_time_series!(data::SystemData, components, time_series::TimeSeriesData)
    metadata_type = time_series_data_to_metadata(typeof(time_series))
    ts_metadata = metadata_type(time_series)
    for component in components
        _attach_time_series_and_serialize!(data, component, ts_metadata, time_series)
    end
end

function _attach_time_series_and_serialize!(
    data::SystemData,
    component::InfrastructureSystemsComponent,
    ts_metadata::T,
    ts::TimeSeriesData;
    skip_if_present=false,
) where {T <: TimeSeriesMetadata}
    _validate_component(data, component)
    check_add_time_series(data.time_series_params, ts)
    check_read_only(data.time_series_storage)
    if has_time_series(component, T, get_name(ts))
        skip_if_present && return
        throw(ArgumentError("time_series $(typeof(ts)) $(get_name(ts)) is already stored"))
    end

    serialize_time_series!(
        data.time_series_storage,
        get_uuid(component),
        get_name(ts_metadata),
        ts,
    )
    add_time_series!(component, ts_metadata, skip_if_present=skip_if_present)
    # Order is important. Set this last in case exceptions are thrown at previous steps.
    set_parameters!(data.time_series_params, ts)
    return
end

function add_time_series_from_file_metadata_internal!(
    data::SystemData,
    ::Type{T},
    cache::TimeSeriesParsingCache,
    file_metadata::TimeSeriesFileMetadata,
) where {T <: InfrastructureSystemsComponent}
    set_component!(file_metadata, data, InfrastructureSystems)
    component = file_metadata.component
    time_series = make_time_series!(cache, file_metadata)
    add_time_series!(data, component, time_series)
    return
end

"""
Remove the time series data for a component.
"""
function remove_time_series!(
    data::SystemData,
    ::Type{T},
    component::InfrastructureSystemsComponent,
    name::String,
) where {T <: TimeSeriesData}
    type = time_series_data_to_metadata(T)
    time_series = get_time_series(type, component, name)
    uuid = get_time_series_uuid(time_series)
    if remove_time_series_metadata!(component, type, name)
        remove_time_series!(data.time_series_storage, uuid, get_uuid(component), name)
    end

    return
end

function remove_time_series!(
    data::SystemData,
    component::InfrastructureSystemsComponent,
    ts_metadata::TimeSeriesMetadata,
)
    uuid = get_time_series_uuid(ts_metadata)
    name = get_name(ts_metadata)
    if remove_time_series_metadata!(component, typeof(ts_metadata), name)
        remove_time_series!(data.time_series_storage, uuid, get_uuid(component), name)
    end

    return
end

"""
Return a time series from TimeSeriesFileMetadata.

# Arguments

  - `cache::TimeSeriesParsingCache`: cached data
  - `ts_file_metadata::TimeSeriesFileMetadata`: metadata
  - `resolution::{Nothing, Dates.Period}`: skip any time_series that don't match this resolution
"""
function make_time_series!(
    cache::TimeSeriesParsingCache,
    ts_file_metadata::TimeSeriesFileMetadata,
)
    info = add_time_series_info!(cache, ts_file_metadata)
    return ts_file_metadata.time_series_type(info)
end

function add_time_series_info!(
    cache::TimeSeriesParsingCache,
    metadata::TimeSeriesFileMetadata,
)
    time_series = _add_time_series_info!(cache, metadata)
    info = TimeSeriesParsedInfo(metadata, time_series)
    @debug "Added TimeSeriesParsedInfo" _group = LOG_GROUP_TIME_SERIES metadata
    return info
end

"""
Checks that the component exists in data and the UUID's match.
"""
function _validate_component(
    data::SystemData,
    component::T,
) where {T <: InfrastructureSystemsComponent}
    name = get_name(component)
    comp = get_component(T, data.components, name)
    if isnothing(comp)
        comp = get_masked_component(T, data, name)
        if comp === nothing
            throw(ArgumentError("no $T with name=$name is stored"))
        end
    end

    user_uuid = get_uuid(component)
    ps_uuid = get_uuid(comp)
    if user_uuid != ps_uuid
        throw(
            ArgumentError(
                "comp UUID doesn't match, perhaps it was copied?; " *
                "$T name=$(get_name(component)) user=$user_uuid system=$ps_uuid",
            ),
        )
    end
end

function compare_values(x::SystemData, y::SystemData; compare_uuids=false)
    match = true
    for name in fieldnames(SystemData)
        val_x = getfield(x, name)
        val_y = getfield(y, name)
        if name == :time_series_storage && typeof(val_x) != typeof(val_y)
            @warn "Cannot compare $(typeof(val_x)) and $(typeof(val_y))"
            # TODO 1.0: workaround for not being able to convert Hdf5TimeSeriesStorage to
            # InMemoryTimeSeriesStorage
            continue
        end
        if !compare_values(val_x, val_y, compare_uuids=compare_uuids)
            @error "SystemData field = $name does not match" getfield(x, name) getfield(
                y,
                name,
            )
            match = false
        end
    end

    return match
end

function remove_component!(::Type{T}, data::SystemData, name) where {T}
    return remove_component!(T, data.components, name)
end

function remove_component!(data::SystemData, component)
    return remove_component!(data.components, component)
end

function remove_components!(::Type{T}, data::SystemData) where {T}
    return remove_components!(T, data.components)
end

"""
Removes the component from the main container and adds it to the masked container.
"""
function mask_component!(data::SystemData, component::InfrastructureSystemsComponent)
    remove_component!(data.components, component, remove_time_series=false)
    set_time_series_storage!(component, nothing)
    return add_masked_component!(
        data,
        component,
        skip_validation=true,  # validation has already occurred
        allow_existing_time_series=true,
    )
end

function clear_time_series!(data::SystemData)
    clear_time_series!(data.time_series_storage)
    clear_time_series!(data.components)
    reset_info!(data.time_series_params)
    return
end

function iterate_components_with_time_series(data::SystemData)
    return Iterators.Flatten((
        iterate_components_with_time_series(data.components),
        iterate_components_with_time_series(data.masked_components),
    ))
end

"""
Removes all time series of a particular type from a System.

# Arguments

  - `data::SystemData`: system
  - `type::Type{<:TimeSeriesData}`: Type of time series objects to remove.
"""
function remove_time_series!(data::SystemData, ::Type{T}) where {T <: TimeSeriesData}
    for component in iterate_components_with_time_series(data)
        for ts_metadata in list_time_series_metadata(component)
            if time_series_metadata_to_data(ts_metadata) <: T
                remove_time_series!(data, component, ts_metadata)
            end
        end
    end
    counts = get_time_series_counts(data)
    if counts[3] == 0 # no more forecast objects
        if counts[2] == 0 # no more static time series objects
            reset_info!(data.time_series_params)
        else
            reset_info!(data.time_series_params.forecast_params)
        end
    end
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
    filter_func=nothing;
    type=nothing,
    name=nothing,
)
    Channel() do channel
        for component in iterate_components_with_time_series(data)
            for time_series in
                get_time_series_multiple(component, filter_func; type=type, name=name)
                put!(channel, time_series)
            end
        end
    end
end

# These are guaranteed to be consistent already.
check_time_series_consistency(::SystemData, ::Type{<:Forecast}) = nothing

function check_time_series_consistency(data::SystemData, ::Type{SingleTimeSeries})
    first_initial_timestamp = Dates.now()
    first_len = 0
    found_first = false
    for component in iterate_components_with_time_series(data)
        container = get_time_series_container(component)
        for key in keys(container.data)
            ts_metadata = container.data[key]
            if time_series_metadata_to_data(ts_metadata) === SingleTimeSeries
                initial_timestamp = get_initial_timestamp(ts_metadata)
                len = get_length(ts_metadata)
                if !found_first
                    first_initial_timestamp = get_initial_timestamp(ts_metadata)
                    first_len = get_length(ts_metadata)
                    found_first = true
                else
                    if initial_timestamp != first_initial_timestamp
                        throw(
                            InvalidValue(
                                "SingleTimeSeries initial timestamps are inconsistent; $initial_timestamp != $first_initial_timestamp",
                            ),
                        )
                    end
                    if len != first_len
                        throw(
                            InvalidValue(
                                "SingleTimeSeries lengths are inconsistent; $len != $first_len",
                            ),
                        )
                    end
                end
            end
        end
    end

    return first_initial_timestamp, first_len
end

"""
Return a tuple of counts of components with time series and total time series and forecasts.
"""
function get_time_series_counts(data::SystemData)
    component_count = 0
    static_time_series_count = 0
    forecast_count = 0
    for component in iterate_components_with_time_series(data)
        component_count += 1
        _ts_count, _forecast_count = get_num_time_series(component)
        static_time_series_count += _ts_count
        forecast_count += _forecast_count
    end

    return (component_count, static_time_series_count, forecast_count)
end

"""
Transform all instances of SingleTimeSeries to DeterministicSingleTimeSeries.

Any existing DeterministicSingleTimeSeries forecasts will be deleted even if the inputs are
invalid.
"""
function transform_single_time_series!(
    data::SystemData,
    ::Type{T},
    horizon::Int,
    interval::Dates.Period,
) where {T <: DeterministicSingleTimeSeries}
    remove_time_series!(data, DeterministicSingleTimeSeries)
    params = nothing
    set_params = false
    for component in iterate_components_with_time_series(data)
        if params === nothing
            params = get_single_time_series_transformed_parameters(
                component,
                T,
                horizon,
                interval,
            )
            if params === nothing
                # This component doesn't have SingleTimeSeries.
                continue
            end
            # This will throw if there is another forecast type with conflicting parameters.
            check_params_compatibility(data.time_series_params, params)
        end

        if transform_single_time_series_internal!(component, T, params) && !set_params
            set_parameters!(data.time_series_params, params)
            set_params = true
        end
    end
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
            @warn "no component category=$category name=$(metadata.component_name)"
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
            throw(
                DataFormatError(
                    "duplicate names type=$(category) name=$(metadata.component_name)",
                ),
            )
        end
    end
end

"""
Parent object should call this prior to serialization so that SystemData can store the
appropriate path information for the time series data.
"""
function prepare_for_serialization!(data::SystemData, filename::AbstractString; force=false)
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
    return
end

function serialize(data::SystemData)
    @debug "serialize SystemData" _group = LOG_GROUP_SERIALIZATION
    json_data = Dict()
    for field in (:components, :masked_components, :time_series_params, :internal)
        json_data[string(field)] = serialize(getfield(data, field))
    end

    ext = get_ext(data.internal)
    if !haskey(ext, "serialization_directory")
        error("prepare_for_serialization! was not called")
    end
    directory = pop!(ext, "serialization_directory")
    base = pop!(ext, "basename")
    isempty(ext) && clear_ext!(data.internal)

    if isempty(data.time_series_storage)
        json_data["time_series_compression_enabled"] =
            get_compression_settings(data.time_series_storage).enabled
        json_data["time_series_in_memory"] =
            data.time_series_storage isa InMemoryTimeSeriesStorage
    else
        time_series_base_name = base * "_" * TIME_SERIES_STORAGE_FILE
        time_series_storage_file = joinpath(directory, time_series_base_name)
        serialize(data.time_series_storage, time_series_storage_file)
        json_data["time_series_storage_file"] = time_series_base_name
        json_data["time_series_storage_type"] = string(typeof(data.time_series_storage))
    end

    descriptor_base_name = base * "_" * VALIDATION_DESCRIPTOR_FILE
    descriptor_file = joinpath(directory, descriptor_base_name)
    descriptors = Dict("struct_validation_descriptors" => data.validation_descriptors)
    text = JSON3.write(descriptors)
    open(descriptor_file, "w") do io
        write(io, text)
    end
    json_data["validation_descriptor_file"] = descriptor_base_name
    json_data["version_info"] = serialize_julia_info()
    return json_data
end

function deserialize(
    ::Type{SystemData},
    raw::Dict;
    time_series_read_only=false,
    time_series_directory=nothing,
)
    @debug "deserialize" raw _group = LOG_GROUP_SERIALIZATION
    time_series_params = deserialize(TimeSeriesParameters, raw["time_series_params"])
    # The code calling this function must have changed to this directory.
    if !isfile(raw["validation_descriptor_file"])
        error(
            "validation descriptor file $(raw["validation_descriptor_file"]) does not exist",
        )
    end
    validation_descriptors = read_validation_descriptor(raw["validation_descriptor_file"])

    if haskey(raw, "time_series_storage_file")
        if !isfile(raw["time_series_storage_file"])
            error("time series file $(raw["time_series_storage_file"]) does not exist")
        end
        # TODO: need to address this limitation
        if strip_module_name(raw["time_series_storage_type"]) == "InMemoryTimeSeriesStorage"
            @info "Deserializing with InMemoryTimeSeriesStorage is currently not supported. Using HDF"
            #hdf5_storage = Hdf5TimeSeriesStorage(raw["time_series_storage_file"], true)
            #time_series_storage = InMemoryTimeSeriesStorage(hdf5_storage)
        end
        time_series_storage = from_file(
            Hdf5TimeSeriesStorage,
            raw["time_series_storage_file"];
            read_only=time_series_read_only,
            directory=time_series_directory,
        )
    else
        time_series_storage = make_time_series_storage(
            in_memory=raw["time_series_compression_enabled"],
            compression=CompressionSettings(enabled=raw["time_series_in_memory"]),
            directory=time_series_directory,
        )
    end

    internal = deserialize(InfrastructureSystemsInternal, raw["internal"])
    @debug "deserialize" _group = LOG_GROUP_SERIALIZATION validation_descriptors time_series_storage internal
    sys = SystemData(
        time_series_params,
        validation_descriptors,
        time_series_storage,
        internal,
    )
    # Note: components need to be deserialized by the parent so that they can go through
    # the proper checks.
    return sys
end

# Redirect functions to Components and TimeSeriesContainer

add_component!(data::SystemData, component; kwargs...) =
    add_component!(data.components, component; kwargs...)

add_masked_component!(data::SystemData, component; kwargs...) = add_component!(
    data.masked_components,
    component;
    allow_existing_time_series=true,
    kwargs...,
)

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
    filter_func::Function,
    ::Type{T},
    data::SystemData,
) where {T}
    return get_components(T, data.components, filter_func)
end

# Keep this version to support PowerSystems 1.x.
function get_components(
    ::Type{T},
    data::SystemData,
    filter_func::Union{Nothing, Function}=nothing,
) where {T}
    return get_components(T, data.components, filter_func)
end

get_components_by_name(::Type{T}, data::SystemData, args...) where {T} =
    get_components_by_name(T, data.components, args...)

function get_masked_components(
    ::Type{T},
    data::SystemData,
    filter_func::Union{Nothing, Function}=nothing,
) where {T}
    return get_components(T, data.masked_components, filter_func)
end

get_masked_components_by_name(::Type{T}, data::SystemData, args...) where {T} =
    get_components_by_name(T, data.masked_components, args...)

get_masked_component(::Type{T}, data::SystemData, name) where {T} =
    get_component(T, data.masked_components, name)

function get_masked_component(data::SystemData, uuid::Base.UUID)
    for component in get_masked_components(InfrastructureSystemsComponent, data)
        if get_uuid(component) == uuid
            return component
        end
    end

    @error "no component with UUID $uuid is stored"
    return nothing
end

get_forecast_initial_times(data::SystemData) =
    get_forecast_initial_times(data.time_series_params)
get_forecast_total_period(data::SystemData) =
    get_forecast_total_period(data.time_series_params)
get_forecast_window_count(data::SystemData) =
    get_forecast_window_count(data.time_series_params)
get_forecast_horizon(data::SystemData) = get_forecast_horizon(data.time_series_params)
get_forecast_initial_timestamp(data::SystemData) =
    get_forecast_initial_timestamp(data.time_series_params)
get_forecast_interval(data::SystemData) = get_forecast_interval(data.time_series_params)
get_time_series_resolution(data::SystemData) =
    get_time_series_resolution(data.time_series_params)

clear_components!(data::SystemData) = clear_components!(data.components)

function check_components(data::SystemData, args...)
    check_components(data.components, args...)
    check_components(data.masked_components, args...)
    return
end

check_component(data::SystemData, component) = check_component(data.components, component)

get_compression_settings(data::SystemData) =
    get_compression_settings(data.time_series_storage)

set_name!(data::SystemData, component, name) = set_name!(data.components, component, name)
