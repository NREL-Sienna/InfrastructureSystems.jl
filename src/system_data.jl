
mutable struct SystemData <: InfrastructureSystemsType
    components::Components
    forecast_metadata::ForecastMetadata
    validation_descriptors::Vector
    time_series_storage::TimeSeriesStorage
end

function SystemData(; validation_descriptor_file=nothing, time_series_in_memory=false)
    if isnothing(validation_descriptor_file)
        validation_descriptors = Vector()
    else
        validation_descriptors = read_validation_descriptor(validation_descriptor_file)
    end

    components = Components(validation_descriptors)
    ts_storage = make_time_series_storage(; in_memory=time_series_in_memory)
    return SystemData(components, ForecastMetadata(), validation_descriptors, ts_storage)
end

"""
    SystemData(filename::AbstractString)

Deserialize SystemData from a JSON file.
"""
function SystemData(filename::AbstractString)
    return from_json(SystemData, filename)
end

"""
    add_forecasts!(data::SystemData, component::InfrastructureSystemsType, forecasts)

Add forecasts.

# Arguments
- `data::SystemData`: system
- `component::InfrastructureSystemsType`: component
- `forecasts`: iterable (array, iterator, etc.) of Forecast values

Throws DataFormatError if
- A forecast has a different resolution than others.
- A forecast has a different horizon than others.

Throws ArgumentError if the component is not stored in the system.

"""
function add_forecasts!(data::SystemData, component::InfrastructureSystemsType, forecasts)
    error("exit")
    # TODO DT: need to create ForecastInternal for each and then store the time arrays.
    if length(forecasts) == 0
        return
    end

    _validate_component(data, component)
    _check_add_forecasts!(data.forecast_metadata, forecasts)
    foreach(x -> add_forecast!(component, x), forecasts)
end

# TODO DT: all add_forecast* functions in this file should take Forecast and not ForecastInternal

"""
    add_forecasts!(data::SystemData, metadata_file::AbstractString; resolution=nothing)

Adds forecasts from a metadata file or metadata descriptors.

# Arguments
- `data::SystemData`: system
- `metadata_file::AbstractString`: metadata file for timeseries
  that includes an array of TimeseriesFileMetadata instances or a vector.
- `resolution::DateTime.Period=nothing`: skip forecast that don't match this resolution.
"""
function add_forecasts!(
                        ::Type{T},
                        data::SystemData,
                        metadata_file::AbstractString;
                        resolution=nothing,
                       ) where T <: InfrastructureSystemsType
    metadata = read_timeseries_metadata(metadata_file)
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
    forecast_infos = ForecastInfos()  # TODO add word Cache

    for metadata in timeseries_metadata
        add_forecast!(T, data, forecast_infos, metadata; resolution=resolution)
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
    _check_add_forecasts!(data.forecast_metadata, [forecast])
    add_forecast!(component, forecast)
    # TODO DT: can this be atomic with forecast addition?
    add_time_series!(data.time_series_storage, component, get_label(forecast), ts_data)
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
    ts = read_timeseries(filename, component_name)
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
                       forecast_infos::ForecastInfos,
                       metadata::TimeseriesFileMetadata;
                       resolution=nothing,
                      ) where T <: InfrastructureSystemsType
    set_component!(metadata, data, InfrastructureSystems)
    component = metadata.component
    forecast, ts_data = make_forecast!(forecast_infos, metadata; resolution=resolution)
    if !isnothing(forecast)
        add_forecast!(data, component, forecast, ts_data)
    end
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
                        forecast_infos::ForecastInfos,
                        timeseries_metadata::TimeseriesFileMetadata;
                        resolution=nothing,
                       )
    forecast_info = add_forecast_info!(forecast_infos, timeseries_metadata)
    return _make_forecast(forecast_info, resolution)
end

"""
    get_forecast(
                 ::Type{T},
                 data::SystemData,
                 component::Component,
                 initial_time::Dates.DateTime,
                 label::AbstractString,
                ) where T <: Forecast

Return a forecast for the entire time series range stored for these parameters.
"""
function get_forecast(
                      ::Type{T},
                      data::SystemData,
                      component::InfrastructureSystemsType,
                      initial_time::Dates.DateTime,
                      label::AbstractString,
                     ) where T <: Forecast
    forecast_type = forecast_external_to_internal(T)
    forecast = get_forecast(forecast_type, component, initial_time, label)
    ts = get_time_series(data.time_series_storage, get_time_series_uuid(forecast))
    return make_public_forecast(forecast, ts)
end

"""
    get_forecast(
                 ::Type{T},
                 data::SystemData,
                 component::InfrastructureSystemsType,
                 initial_time::Dates.DateTime,
                 label::AbstractString,
                 horizon::Int,
                ) where T <: Forecast

Return a forecast for a subset of the time series range stored for these parameters.
"""
function get_forecast(
                      ::Type{T},
                      data::SystemData,
                      component::InfrastructureSystemsType,
                      initial_time::Dates.DateTime,
                      label::AbstractString,
                      horizon::Int,
                     ) where T <: Forecast
    resolution = get_forecasts_resolution(data)
    forecast = get_forecast(
        forecast_external_to_internal(T),
        component,
        initial_time,
        resolution,
        get_forecasts_horizon(data),
        label,
        horizon,
    )
    index = Int((initial_time - get_initial_time(forecast)) / resolution) + 1
    ts = get_time_series(
        data.time_series_storage,
        get_time_series_uuid(forecast);
        index=index,
        len=horizon,
    )

    return make_public_forecast(forecast, ts)
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

function _make_forecasts(forecast_infos::ForecastInfos, resolution)
    forecasts = Vector{Forecast}()

    for forecast_info in forecast_infos.forecasts
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

function add_forecast_info!(infos::ForecastInfos, metadata::TimeseriesFileMetadata)
    timeseries = _add_forecast_info!(infos, metadata.data_file, metadata.component_name)
    forecast_info = ForecastInfo(metadata, timeseries)
    @debug "Added ForecastInfo" metadata
    return forecast_info
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

#function convert_forecasts!(
#                            data::SystemData,
#                            raw::NamedTuple,
#                            component_cache::Dict,
#                           ) where T <: Forecast
#    return convert_type!(data.forecasts, raw.forecasts, component_cache)
#end

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
    remove_component_time_series!(data, component)
end

function remove_component!(data::SystemData, component)
    remove_component_time_series!(data, component)
    remove_component!(data.components, component)
end

function remove_components!(::Type{T}, data::SystemData) where T
    components = remove_components!(T, data.components)
    foreach(x -> remove_component_time_series!(data, x), components)
end

function remove_component_time_series!(data::SystemData, component)
    for (uuid, label) in get_time_series_uuids(component)
        remove_time_series!(data.time_series_storage, uuid, component, label)
    end
end

function get_time_series(data::SystemData, forecast::Forecast)
    # TODO DT: handle offsets
    return get_time_series(data.time_series_storage, get_time_series_uuid(forecast))
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
                public_forecast = 
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

function get_forecasts_interval(data::SystemData)
    initial_times = get_forecast_initial_times(data)
    if length(initial_times) <= 1
        return UNINITIALIZED_PERIOD
    end

    return initial_times[2] - initial_times[1]
end

function JSON2.read(io::IO, ::Type{SystemData})
    # WARNING: This only works for components defined in InfrastructureSystems.
    sys = SystemData()
    component_cache = Dict{Base.UUID, InfrastructureSystemsType}()

    raw = JSON2.read(io, NamedTuple)
    for c_type_sym in get_component_types_raw(SystemData, raw)
        c_type = getfield(InfrastructureSystems,
                          Symbol(strip_module_name(string(c_type_sym))))
        for component in get_components_raw(SystemData, c_type, raw)
            comp = convert_type(c_type, component)
            add_component!(sys, comp)
            component_cache[get_uuid(comp)] = comp
        end
    end

    convert_forecasts!(sys, raw, component_cache)

    sys.validation_descriptors = raw.validation_descriptors
    return sys
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
set_component!(metadata::TimeseriesFileMetadata, data::SystemData, mod::Module) =
    set_component!(metadata, data.components, mod)
validate_forecast_consistency(data::SystemData) = validate_forecast_consistency(data.components)
