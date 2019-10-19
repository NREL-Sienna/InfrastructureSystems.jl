
const TIME_SERIES_STORAGE_FILE = "time_series_storage.h5"

mutable struct SystemData <: InfrastructureSystemsType
    components::Components
    forecast_metadata::ForecastMetadata
    validation_descriptors::Vector
    time_series_storage::TimeSeriesStorage
    time_series_storage_file::Union{Nothing, String}  # only valid during serialization
    internal::InfrastructureSystemsInternal
end

function SystemData(; validation_descriptor_file=nothing, time_series_in_memory=false)
    if isnothing(validation_descriptor_file)
        validation_descriptors = Vector()
    else
        validation_descriptors = read_validation_descriptor(validation_descriptor_file)
    end

    ts_storage = make_time_series_storage(; in_memory=time_series_in_memory)
    components = Components(ts_storage, validation_descriptors)
    return SystemData(components, ForecastMetadata(), validation_descriptors, ts_storage,
                      nothing, InfrastructureSystemsInternal())
end

function SystemData(forecast_metadata, validation_descriptors, time_series_storage,
                    internal)
    components = Components(time_series_storage, validation_descriptors)
    return SystemData(components, forecast_metadata, validation_descriptors,
                      time_series_storage, nothing, internal)
end

"""
    SystemData(filename::AbstractString)

Deserialize SystemData from a JSON file.
"""
function SystemData(filename::AbstractString)
    return from_json(SystemData, filename)
end

"""
    add_forecasts!(
                   ::Type{T},
                   data::SystemData,
                   metadata_file::AbstractString,
                   label_mapping::Dict{Tuple{String, String}, String};
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
                        metadata_file::AbstractString,
                        label_mapping::Dict{Tuple{String, String}, String};
                        resolution=nothing,
                       ) where T <: InfrastructureSystemsType
    metadata = read_time_series_metadata(metadata_file, label_mapping)
    return add_forecasts!(T, data, metadata; resolution=resolution)
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
                        resolution=nothing
                       ) where T <: InfrastructureSystemsType
    forecast_cache = ForecastCache()

    for metadata in timeseries_metadata
        add_forecast!(T, data, forecast_cache, metadata; resolution=resolution)
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
    add_time_series!(data.time_series_storage, get_uuid(component), get_label(forecast),
                     ts_data)
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
                       scaling_factor::Union{String, Float64}=1.0,
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
                       scaling_factor::Union{String, Float64}=1.0,
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
                       scaling_factor::Union{String, Float64}=1.0;
                       timestamp=:timestamp,
                      )
    timeseries = TimeSeries.TimeArray(df; timestamp=timestamp)
    add_forecast!(data, timeseries, component, label, scaling_factor)
end

function add_forecast!(
                       ::Type{T},
                       data::SystemData,
                       forecast_cache::ForecastCache,
                       metadata::TimeseriesFileMetadata;
                       resolution=nothing,
                      ) where T <: InfrastructureSystemsType
    set_component!(metadata, data, InfrastructureSystems)
    component = metadata.component
    forecast, ts_data = make_forecast!(forecast_cache, metadata; resolution=resolution)
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
                         ) where T <: Forecast
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
                        resolution=nothing,
                       )
    forecast_info = add_forecast_info!(forecast_cache, timeseries_metadata)
    return _make_forecast(forecast_info, resolution)
end

function forecast_external_to_internal(::Type{T}) where T <: Forecast
    if T <: Deterministic
        forecast_type = DeterministicInternal
    elseif T <: Probabilistic
        forecast_type = ProbabilisticInternal
    elseif T <: ScenarioBased
        forecast_type = ScenarioBasedInternal
    else
        @assert false
    end

    return forecast_type
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
    timeseries = _add_forecast_info!(forecast_cache, metadata.data_file,
                                     metadata.component_name)
    forecast_info = ForecastInfo(metadata, timeseries)
    @debug "Added ForecastInfo" metadata
    return forecast_info
end

"""
    generate_initial_times(data::SystemData, interval::Dates.Period, horizon::Int)

Generates all possible initial times for the stored forecasts. This should be used when
contiguous forecasts have been stored in chunks, such as a one-year forecast broken up into
365 one-day forecasts.

Throws ArgumentError if there are no forecasts stored, interval is not a multiple of the
system's forecast resolution, or if the stored forecasts have overlapping timestamps.
"""
function generate_initial_times(data::SystemData, interval::Dates.Period, horizon::Int)
    existing_initial_times = get_forecast_initial_times(data)
    if length(existing_initial_times) == 0
        throw(ArgumentError("no forecasts are stored"))
    end

    initial_time, total_horizon = check_contiguous_forecasts(data, existing_initial_times)
    resolution = Dates.Second(get_forecasts_resolution(data))
    interval = Dates.Second(interval)

    if interval % resolution != Dates.Second(0)
        throw(ArgumentError(
            "interval=$interval is not a multiple of resolution=$resolution"
        ))
    end

    step_length = Int(interval / resolution)
    last_initial_time_index = total_horizon - horizon
    num_initial_times = Int(trunc(last_initial_time_index / step_length)) + 1
    initial_times = Vector{Dates.DateTime}(undef, num_initial_times)

    index = 1
    for i in range(0, step=step_length, stop=last_initial_time_index)
        initial_times[index] = initial_time + i * resolution
        index += 1
    end

    @assert index - 1 == num_initial_times
    return initial_times
end

"""
Throws ArgumentError if the forecasts are not in consecutive order.
"""
function check_contiguous_forecasts(data::SystemData, _initial_times)
    first_initial_time = _initial_times[1]
    resolution = get_forecasts_resolution(data)
    horizon = get_forecasts_horizon(data)
    total_horizon = horizon * length(_initial_times)

    if length(_initial_times) == 1
        return first_initial_time, total_horizon
    end

    for i in range(2, stop=length(_initial_times))
        if _initial_times[i] != _initial_times[i - 1] + resolution * horizon
            throw(ArgumentError(
                "generate_initial_times is not allowed with overlapping timestamps"
            ))
        end
    end

    return first_initial_time, total_horizon
end

"""
Checks that the component exists in data and the UUID's match.
"""
function _validate_component(
                             data::SystemData,
                             component::T,
                            ) where T <: InfrastructureSystemsType
    comp = get_component(T, data.components, get_name(component))
    if isnothing(comp)
        throw(ArgumentError("no $T with name=$(get_name(component)) is stored"))
    end

    user_uuid = get_uuid(component)
    ps_uuid = get_uuid(comp)
    if user_uuid != ps_uuid
        throw(ArgumentError(
            "comp UUID doesn't match, perhaps it was copied?; " *
            "$T name=$(get_name(component)) user=$user_uuid system=$ps_uuid"
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
                           ) where T <: InfrastructureSystemsType
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

function remove_component!(::Type{T}, data::SystemData, name) where T
    component = remove_component!(T, data.components, name)
end

function remove_component!(data::SystemData, component)
    remove_component!(data.components, component)
end

function remove_components!(::Type{T}, data::SystemData) where T
    remove_components!(T, data.components)
end

function clear_forecasts!(data::SystemData)
    clear_forecasts!(data.components)
    clear_time_series!(data.time_series_storage)
end

function iterate_forecasts(data::SystemData)
    Channel() do channel
        for component in iterate_components_with_forecasts(data.components)
            for forecast in iterate_forecasts(component)
                time_series = get_time_series(data.time_series_storage,
                                              get_time_series_uuid(forecast))
                put!(channel, make_public_forecast(forecast, time_series))
            end
        end
    end
end

function get_forecast_initial_times(
                                    ::Type{T},
                                    data::SystemData,
                                    component::InfrastructureSystemsType
                                   ) where T <: Forecast
    forecast_type = forecast_external_to_internal(T)
    return get_forecast_initial_times(forecast_type, component)
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
    prepare_for_serialization(data::SystemData, filename::AbstractString)

Parent object should call this prior to serialization so that SystemData can store the
appropriate path information for the time series data.
"""
function prepare_for_serialization(data::SystemData, filename::AbstractString)
    dir = dirname(filename)
    base = splitext(basename(filename))[1]
    data.time_series_storage_file = joinpath(dir, base * "_" * TIME_SERIES_STORAGE_FILE)
end

function JSON2.write(io::IO, data::SystemData)
    return JSON2.write(io, encode_for_json(data))
end

function JSON2.write(data::SystemData)
    return JSON2.write(encode_for_json(data))
end

function encode_for_json(data::SystemData)
    if isnothing(data.time_series_storage_file)
        data.time_series_storage_file = TIME_SERIES_STORAGE_FILE
    end

    json_data = Dict()
    for field in (:components, :forecast_metadata, :validation_descriptors,
                  :time_series_storage_file, :internal)
        json_data[string(field)] = getfield(data, field)
    end

    serialize(data.time_series_storage, data.time_series_storage_file)
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
                    ) where T <: InfrastructureSystemsType
    forecast_metadata = convert_type(ForecastMetadata, raw.forecast_metadata)
    # TODO: This code doesn't allow for remembering the type of TimeSeriesStorage used by
    # the original SystemData. It will always use Hdf5TimeSeriesStorage after
    # deserialization. This could be fixed. Need to build an InMemoryTimeSeriesStorage
    # object by iterating over an Hdf5TimeSeriesStorage file.
    time_series_storage = from_file(Hdf5TimeSeriesStorage, raw.time_series_storage_file)

    # OPT: This looks odd and is wasteful.
    # JSON2 creates NamedTuples recursively. JSON creates dicts, which is what we need.
    # Could be optimized.
    validation_descriptors = JSON.parse(JSON2.write(raw.validation_descriptors))

    internal = convert_type(InfrastructureSystemsInternal, raw.internal)
    sys = SystemData(forecast_metadata, validation_descriptors, time_series_storage,
                     internal)
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
        c_type = getfield(InfrastructureSystems,
                          Symbol(strip_module_name(string(c_type_sym))))
        for component in get_components_raw(SystemData, c_type, raw)
            comp = convert_type(c_type, component)
            add_component!(sys, comp)
        end
    end

    return
end

# Redirect functions to Components and Forecasts

add_component!(data::SystemData, component; kwargs...) = add_component!(
    data.components, component; kwargs...
)
iterate_components(data::SystemData) = iterate_components(data.components)

get_component(::Type{T}, data::SystemData, args...) where T = get_component(
    T, data.components, args...
)
get_components(::Type{T}, data::SystemData) where T = get_components(T, data.components)
get_components_by_name(::Type{T}, data::SystemData, args...) where T =
    get_components_by_name(T, data.components, args...)

#get_component_forecasts(::Type{T}, data::SystemData, args...) where T =
#    get_component_forecasts(T, data.forecasts, args...)
#get_forecasts(::Type{T}, data::SystemData, component, args...) where T = get_forecasts(
#    T, component, args...
#)
get_forecast_initial_times(data::SystemData) = get_forecast_initial_times(data.components)
get_forecasts_initial_time(data::SystemData) = get_forecasts_initial_time(data.components)
get_forecasts_last_initial_time(data::SystemData) = get_forecasts_last_initial_time(data.components)
get_forecasts_horizon(data::SystemData) = get_forecasts_horizon(data.forecast_metadata)
get_forecasts_resolution(data::SystemData) = get_forecasts_resolution(data.forecast_metadata)
clear_components!(data::SystemData) = clear_components!(data.components)
set_component!(metadata::TimeseriesFileMetadata, data::SystemData, mod::Module) =
    set_component!(metadata, data.components, mod)
validate_forecast_consistency(data::SystemData) = validate_forecast_consistency(data.components)
