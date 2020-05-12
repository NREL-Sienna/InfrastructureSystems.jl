
const TIME_SERIES_STORAGE_FILE = "time_series_storage.h5"
const VALIDATION_DESCRIPTOR_FILE = "validation_descriptors.json"

"""
    mutable struct SystemData <: InfrastructureSystemsType
        components::Components
        forecast_metadata::ForecastMetadata
        validation_descriptors::Vector
        time_series_storage::TimeSeriesStorage
        time_series_storage_file::Union{Nothing, String}
        internal::InfrastructureSystemsInternal
    end

Container for system components and time series data
"""
mutable struct SystemData <: InfrastructureSystemsType
    components::Components
    forecast_metadata::ForecastMetadata
    time_series_storage::TimeSeriesStorage
    validation_descriptors::Vector
    internal::InfrastructureSystemsInternal
end

"""
    SystemData(; validation_descriptor_file = nothing, time_series_in_memory = false)

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
        ForecastMetadata(),
        ts_storage,
        validation_descriptors,
        InfrastructureSystemsInternal(),
    )
end

function SystemData(
    forecast_metadata,
    validation_descriptors,
    time_series_storage,
    internal,
)
    components = Components(time_series_storage, validation_descriptors)
    return SystemData(
        components,
        forecast_metadata,
        time_series_storage,
        validation_descriptors,
        internal,
    )
end

"""
    SystemData(filename::AbstractString)

Construct SystemData from a JSON file.
"""
function SystemData(filename::AbstractString)
    return from_json(SystemData, filename)
end

"""Deserializes a SystemData from a JSON file."""
function from_json(::Type{SystemData}, filename::String)
    # File paths in the JSON are relative. Temporarily change to this directory in order
    # to find all dependent files.
    orig_dir = pwd()
    cd(dirname(filename))
    try
        return open(filename) do io
            from_json(io, SystemData)
        end
    finally
        cd(orig_dir)
    end
end

"""
    add_forecasts!(
                   ::Type{T},
                   data::SystemData,
                   metadata_file::AbstractString,
                   resolution=nothing,
                  ) where T <: InfrastructureSystemsType

Adds forecasts from a metadata file or metadata descriptors.

# Arguments
- `::Type{T}`: forecasted component type; may be abstract
- `data::SystemData`: system
- `metadata_file::AbstractString`: metadata file for timeseries
  that includes an array of TimeseriesFileMetadata instances or a vector.
- `resolution::DateTime.Period=nothing`: skip forecast that don't match this resolution.
"""
function add_forecasts!(
    ::Type{T},
    data::SystemData,
    metadata_file::AbstractString;
    resolution = nothing,
) where {T <: InfrastructureSystemsType}
    metadata = read_time_series_metadata(metadata_file)
    return add_forecasts!(T, data, metadata; resolution = resolution)
end

"""
    add_forecasts!(
                   data::SystemData,
                   timeseries_metadata::Vector{TimeseriesFileMetadata};
                   resolution=nothing,
                  )

Adds forecasts from a metadata file or metadata descriptors.

# Arguments
- `data::SystemData`: system
- `timeseries_metadata::Vector{TimeseriesFileMetadata}`: metadata for timeseries
- `resolution::DateTime.Period=nothing`: skip forecast that don't match this resolution.
"""
function add_forecasts!(
    ::Type{T},
    data::SystemData,
    timeseries_metadata::Vector{TimeseriesFileMetadata};
    resolution = nothing,
) where {T <: InfrastructureSystemsType}
    forecast_cache = ForecastCache()

    for metadata in timeseries_metadata
        add_forecast!(T, data, forecast_cache, metadata; resolution = resolution)
    end
end

"""
    add_forecast!(data::SystemData, forecast)

Add a forecast.

# Arguments
- `data::SystemData`: infrastructure
- `forecast`: Any object of subtype forecast

Throws ArgumentError if the forecast's component is not stored in the system.

"""
function add_forecast!(
    data::SystemData,
    component::InfrastructureSystemsType,
    forecast::Forecast,
)
    ts_data = TimeSeriesData(get_data(forecast))
    forecast_internal = make_internal_forecast(forecast, ts_data)
    add_forecast!(data, component, forecast_internal, ts_data)
end

function add_forecast!(
    data::SystemData,
    component::InfrastructureSystemsType,
    forecast::ForecastInternal,
    ts_data::TimeSeriesData,
)
    _validate_component(data, component)
    check_add_forecast!(data.forecast_metadata, forecast)
    add_forecast!(component, forecast)
    # TODO: can this be atomic with forecast addition?
    add_time_series!(
        data.time_series_storage,
        get_uuid(component),
        get_label(forecast),
        ts_data,
    )
end

"""
    add_forecast!(
                  data::SystemData,
                  filename::AbstractString,
                  component::InfrastructureSystemsType,
                  label::AbstractString,
                  scaling_factor::Union{String, Float64}=1.0,
                 )

Add a forecast from a CSV file.

See [`TimeseriesFileMetadata`](@ref) for description of scaling_factor.
"""
function add_forecast!(
    data::SystemData,
    filename::AbstractString,
    component::InfrastructureSystemsType,
    label::AbstractString,
    scaling_factor::Union{String, Float64} = 1.0,
)
    component_name = get_name(component)
    ts = read_time_series(filename, component_name)
    timeseries = ts[Symbol(component_name)]
    _add_forecast!(data, component, label, timeseries, scaling_factor)
end

"""
    add_forecast!(
                  data::SystemData,
                  ta::TimeSeries.TimeArray,
                  component::InfrastructureSystemsType,
                  label::AbstractString,
                  scaling_factor::Union{String, Float64}=1.0,
                 )

Add a forecast to a system from a TimeSeries.TimeArray.

See [`TimeseriesFileMetadata`](@ref) for description of scaling_factor.
"""
function add_forecast!(
    data::SystemData,
    ta::TimeSeries.TimeArray,
    component::InfrastructureSystemsType,
    label::AbstractString,
    scaling_factor::Union{String, Float64} = 1.0,
)
    timeseries = ta[Symbol(get_name(component))]
    _add_forecast!(data, component, label, timeseries, scaling_factor)
end

"""
    add_forecast!(
                  data::SystemData,
                  df::DataFrames.DataFrame,
                  component::InfrastructureSystemsType,
                  label::AbstractString,
                  scaling_factor::Union{String, Float64}=1.0;
                  timestamp=:timestamp,
                 )

Add a forecast to a system from a DataFrames.DataFrame.

See [`TimeseriesFileMetadata`](@ref) for description of scaling_factor.
"""
function add_forecast!(
    data::SystemData,
    df::DataFrames.DataFrame,
    component::InfrastructureSystemsType,
    label::AbstractString,
    scaling_factor::Union{String, Float64} = 1.0;
    timestamp = :timestamp,
)
    timeseries = TimeSeries.TimeArray(df; timestamp = timestamp)
    add_forecast!(data, timeseries, component, label, scaling_factor)
end

function add_forecast!(
    ::Type{T},
    data::SystemData,
    forecast_cache::ForecastCache,
    metadata::TimeseriesFileMetadata;
    resolution = nothing,
) where {T <: InfrastructureSystemsType}
    set_component!(metadata, data, InfrastructureSystems)
    component = metadata.component

    forecast, ts_data = make_forecast!(forecast_cache, metadata; resolution = resolution)
    if !isnothing(forecast)
        add_forecast!(data, component, forecast, ts_data)
    end
end

"""
    remove_forecast!(
                     ::Type{T},
                     data::SystemData,
                     component::InfrastructureSystemsType,
                     initial_time::Dates.DateTime,
                     label::String,
                    ) where T <: Forecast

Remove the time series data for a component.
"""
function remove_forecast!(
    ::Type{T},
    data::SystemData,
    component::InfrastructureSystemsType,
    initial_time::Dates.DateTime,
    label::String,
) where {T <: Forecast}
    type_ = forecast_external_to_internal(T)
    forecast = get_forecast(type_, component, initial_time, label)
    uuid = get_time_series_uuid(forecast)
    # TODO: can this be atomic?
    remove_forecast_internal!(type_, component, initial_time, label)
    remove_time_series!(data.time_series_storage, uuid, get_uuid(component), label)
end

"""
    make_forecast!(timeseries_metadata::TimeseriesFileMetadata;
                   resolution=nothing)

Return a vector of forecasts from TimeseriesFileMetadata.

# Arguments
- `timeseries_metadata::TimeseriesFileMetadata`: metadata
- `resolution::{Nothing, Dates.Period}`: skip any forecasts that don't match this resolution
"""
function make_forecast!(
    forecast_cache::ForecastCache,
    timeseries_metadata::TimeseriesFileMetadata;
    resolution = nothing,
)
    forecast_info = add_forecast_info!(forecast_cache, timeseries_metadata)
    return _make_forecast(forecast_info, resolution)
end

function _add_forecast!(
    data::SystemData,
    component::InfrastructureSystemsType,
    label::AbstractString,
    timeseries::TimeSeries.TimeArray,
    scaling_factor,
)
    timeseries = handle_scaling_factor(timeseries, scaling_factor)
    # TODO: This code path needs to accept a metdata file or parameters telling it which
    # type of forecast to create.
    ts_data = TimeSeriesData(timeseries)
    forecast = DeterministicInternal(label, ts_data)
    add_forecast!(data, component, forecast, ts_data)
end

function _make_forecasts(forecast_cache::ForecastCache, resolution)
    forecasts = Vector{Forecast}()

    for forecast_info in forecast_cache.forecasts
        forecast = _make_forecast(forecast_info)
        if !isnothing(forecast)
            push!(forecasts, forecast)
        end
    end

    return forecasts
end

function _make_forecast(forecast_info::ForecastInfo, resolution)
    len = length(forecast_info.data)
    @assert len >= 2
    timestamps = TimeSeries.timestamp(forecast_info.data)
    res = timestamps[2] - timestamps[1]
    if !isnothing(resolution) && res != resolution
        @debug "Skip forecast with resolution=$res; doesn't match user=$resolution"
        return nothing, nothing
    end

    timeseries = forecast_info.data[Symbol(get_name(forecast_info.component))]
    timeseries = handle_scaling_factor(timeseries, forecast_info.scaling_factor)
    forecast_type = get_forecast_type(forecast_info)
    ts_data = TimeSeriesData(timeseries)
    forecast = forecast_type(forecast_info.label, ts_data)
    @debug "Created $forecast"
    return forecast, ts_data
end

function add_forecast_info!(forecast_cache::ForecastCache, metadata::TimeseriesFileMetadata)
    timeseries =
        _add_forecast_info!(forecast_cache, metadata.data_file, metadata.component_name)
    forecast_info = ForecastInfo(metadata, timeseries)
    @debug "Added ForecastInfo" metadata
    return forecast_info
end

"""
    are_forecasts_contiguous(data::SystemData)

Return true if forecasts are stored contiguously.

Throws ArgumentError if there are no forecasts stored.
"""
function are_forecasts_contiguous(data::SystemData)
    for component in iterate_components_with_forecasts(data.components)
        if has_forecasts(component)
            return are_forecasts_contiguous(component)
        end
    end

    throw(ArgumentError("no forecasts are stored"))
end

"""
    generate_initial_times(
                           data::SystemData,
                           interval::Dates.Period,
                           horizon::Int;
                           initial_time::Union{Nothing, Dates.DateTime}=nothing,
                          )

Generates all possible initial times for the stored forecasts. This should return the same
result regardless of whether the forecasts have been stored as one contiguous array or
chunks of contiguous arrays, such as one 365-day forecast vs 365 one-day forecasts.

Throws ArgumentError if there are no forecasts stored, interval is not a multiple of the
system's forecast resolution, or if the stored forecasts have overlapping timestamps.

# Arguments
- `data::SystemData`: system
- `interval::Dates.Period`: Amount of time in between each initial time.
- `horizon::Int`: Length of each forecast array.
- `initial_time::Union{Nothing, Dates.DateTime}=nothing`: Start with this time. If nothing,
  use the first initial time.
"""
function generate_initial_times(
    data::SystemData,
    interval::Dates.Period,
    horizon::Int;
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
)
    for component in iterate_components_with_forecasts(data.components)
        if has_forecasts(component)
            return generate_initial_times(
                component,
                interval,
                horizon;
                initial_time = initial_time,
            )
        end
    end

    throw(ArgumentError("no forecasts are stored"))
end

"""
Checks that the component exists in data and the UUID's match.
"""
function _validate_component(
    data::SystemData,
    component::T,
) where {T <: InfrastructureSystemsType}
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

function get_component_types_raw(::Type{SystemData}, raw::NamedTuple)
    return get_component_types_raw(Components, raw.components)
end

function get_components_raw(
    ::Type{SystemData},
    ::Type{T},
    raw::NamedTuple,
) where {T <: InfrastructureSystemsType}
    return get_components_raw(Components, T, raw.components)
end

function compare_values(x::SystemData, y::SystemData)::Bool
    match = true
    for key in keys(x.components.data)
        if !compare_values(x.components.data[key], y.components.data[key])
            @debug "System components do not match"
            match = false
        end
    end

    if !compare_values(x.forecast_metadata, y.forecast_metadata)
        @debug "System forecasts do not match"
        match = false
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

function clear_forecasts!(data::SystemData)
    clear_forecasts!(data.components)
    clear_time_series!(data.time_series_storage)
end

function iterate_forecasts(data::SystemData)
    Channel() do channel
        for component in iterate_components_with_forecasts(data.components)
            for forecast in iterate_forecasts(component)
                put!(channel, forecast)
            end
        end
    end
end

"""
Return the time delta between the first two stored forecasts.
if less than two are stored, return Dates.Second(0).
"""
function get_forecasts_interval(data::SystemData)
    initial_times = get_forecast_initial_times(data)
    if length(initial_times) <= 1
        return Dates.Second(0)
    end

    return initial_times[2] - initial_times[1]
end

"""
    get_forecast_counts(data::SystemData)

Return a tuple of counts of components with forecasts and total forecasts.
"""
function get_forecast_counts(data::SystemData)
    component_count = 0
    forecast_count = 0
    for component in iterate_components_with_forecasts(data.components)
        component_count += 1
        forecast_count += get_num_forecasts(component)
    end

    return component_count, forecast_count
end

"""
    set_component!(
                   metadata::TimeseriesFileMetadata,
                   data::SystemData,
                   mod::Module,
                  )

Set the component value in metadata by looking up the category in module.
This requires that category be a string version of a component's abstract type.
Modules can override for custom behavior.
"""
function set_component!(metadata::TimeseriesFileMetadata, data::SystemData, mod::Module)

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
    prepare_for_serialization!(data::SystemData, filename::AbstractString)

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
end

function JSON2.write(io::IO, data::SystemData)
    return JSON2.write(io, encode_for_json(data))
end

function JSON2.write(data::SystemData)
    return JSON2.write(encode_for_json(data))
end

function encode_for_json(data::SystemData)
    json_data = Dict()
    for field in (:components, :forecast_metadata, :internal)
        json_data[string(field)] = getfield(data, field)
    end

    ext = get_ext(data.internal)
    if !haskey(ext, "serialization_directory")
        error("prepare_for_serialization! was not called")
    end
    directory = pop!(ext, "serialization_directory")
    isempty(ext) && clear_ext(data.internal)

    time_series_storage_file = joinpath(directory, TIME_SERIES_STORAGE_FILE)
    serialize(data.time_series_storage, time_series_storage_file)
    json_data["time_series_storage_file"] = TIME_SERIES_STORAGE_FILE
    json_data["time_series_storage_type"] = string(typeof(data.time_series_storage))
    descriptor_file = joinpath(directory, VALIDATION_DESCRIPTOR_FILE)
    text = JSON.json(data.validation_descriptors)
    open(descriptor_file, "w") do io
        write(io, text)
    end
    json_data["validation_descriptor_file"] = VALIDATION_DESCRIPTOR_FILE

    return json_data
end

function JSON2.read(io::IO, ::Type{SystemData})
    raw = JSON2.read(io, NamedTuple)
    sys = deserialize(SystemData, InfrastructureSystemsType, raw)
    return sys
end

function deserialize(
    ::Type{SystemData},
    ::Type{T},
    raw::NamedTuple,
) where {T <: InfrastructureSystemsType}
    forecast_metadata = convert_type(ForecastMetadata, raw.forecast_metadata)
    # The code calling this function must have changed to this directory.
    if !isfile(raw.time_series_storage_file)
        error("time series file $(raw.time_series_storage_file) does not exist")
    end
    if !isfile(raw.validation_descriptor_file)
        error("validation descriptor file $(raw.validation_descriptor_file) does not exist")
    end
    validation_descriptors = read_validation_descriptor(raw.validation_descriptor_file)

    if strip_module_name(raw.time_series_storage_type) == "InMemoryTimeSeriesStorage"
        hdf5_storage = Hdf5TimeSeriesStorage(raw.time_series_storage_file)
        time_series_storage = InMemoryTimeSeriesStorage(hdf5_storage)
    else
        time_series_storage = from_file(Hdf5TimeSeriesStorage, raw.time_series_storage_file)
    end

    internal = convert_type(InfrastructureSystemsInternal, raw.internal)
    sys =
        SystemData(forecast_metadata, validation_descriptors, time_series_storage, internal)
    deserialize_components(T, sys, raw)
    return sys
end

"""
Deserializes components defined in InfrastructureSystems. Parent modules should override
this by changing the component type and module.
"""
function deserialize_components(
    ::Type{InfrastructureSystemsType},
    sys::SystemData,
    raw::NamedTuple,
)
    for c_type_sym in get_component_types_raw(SystemData, raw)
        c_type =
            getfield(InfrastructureSystems, Symbol(strip_module_name(string(c_type_sym))))
        for component in get_components_raw(SystemData, c_type, raw)
            comp = convert_type(c_type, component)
            add_component!(sys, comp)
        end
    end

    return
end

# Redirect functions to Components and Forecasts

add_component!(data::SystemData, component; kwargs...) =
    add_component!(data.components, component; kwargs...)
iterate_components(data::SystemData) = iterate_components(data.components)

get_component(::Type{T}, data::SystemData, args...) where {T} =
    get_component(T, data.components, args...)
function get_components(
    ::Type{T},
    data::SystemData,
    filter_func::Union{Nothing, Function} = nothing,
) where {T}
    return get_components(T, data.components, filter_func)
end

get_components_by_name(::Type{T}, data::SystemData, args...) where {T} =
    get_components_by_name(T, data.components, args...)

#get_component_forecasts(::Type{T}, data::SystemData, args...) where T =
#    get_component_forecasts(T, data.forecasts, args...)
#get_forecasts(::Type{T}, data::SystemData, component, args...) where T = get_forecasts(
#    T, component, args...
#)
get_forecast_initial_times(data::SystemData) = get_forecast_initial_times(data.components)
get_forecasts_initial_time(data::SystemData) = get_forecasts_initial_time(data.components)
get_forecasts_last_initial_time(data::SystemData) =
    get_forecasts_last_initial_time(data.components)
get_forecasts_horizon(data::SystemData) = get_forecasts_horizon(data.forecast_metadata)
get_forecasts_resolution(data::SystemData) =
    get_forecasts_resolution(data.forecast_metadata)
clear_components!(data::SystemData) = clear_components!(data.components)
check_forecast_consistency(data::SystemData) = check_forecast_consistency(data.components)
validate_forecast_consistency(data::SystemData) =
    validate_forecast_consistency(data.components)
