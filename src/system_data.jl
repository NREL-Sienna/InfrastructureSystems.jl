
struct SystemData
    components::Components
    forecasts::Forecasts
    validation_descriptors::Vector
end

function SystemData(; validation_descriptor_file=nothing)
    if isnothing(validation_descriptor_file)
        validation_descriptors = Vector()
    else
        validation_descriptors = read_validation_descriptor(validation_descriptor_file)
    end

    components = Components(validation_descriptors)
    return SystemData(components, Forecasts(), validation_descriptors)
end

"""
    add_forecasts!(data::SystemData, forecasts)

Add forecasts.

# Arguments
- `data::SystemData`: system
- `forecasts`: iterable (array, iterator, etc.) of Forecast values

Throws DataFormatError if
- A component-label pair is not unique within a forecast array.
- A forecast has a different resolution than others.
- A forecast has a different horizon than others.

Throws ArgumentError if the forecast's component is not stored in the system.

"""
function add_forecasts!(data::SystemData, forecasts)
    if length(forecasts) == 0
        return
    end

    for forecast in forecasts
        _validate_forecast(data, forecast)
    end

    _add_forecasts!(data.forecasts, forecasts)
end

"""
    add_forecast!(data::SystemData, forecasts)

Add forecasts.

# Arguments
- `data::SystemData`: infrastructure
- `forecast`: Any object of subtype forecast

Throws ArgumentError if the forecast's component is not stored in the system.

"""
function add_forecast!(data::SystemData, forecast::T) where T <: Forecast
    _validate_forecast(data, forecast)
    _add_forecasts!(data.forecasts, [forecast])
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

"""
    make_forecasts(data::SystemData, metadata_file::AbstractString; resolution=nothing)

Makes forecasts from a metadata file.

# Arguments
- `data::SystemData`: system
- `metadata_file::AbstractString`: path to metadata file
- `mod::Module`: calling module
- `resolution::{Nothing, Dates.Period}`: skip any forecasts that don't match this resolution

See [`TimeseriesFileMetadata`](@ref) for description of what the file should contain.
"""
function make_forecasts(data::SystemData, metadata_file::AbstractString, mod::Module;
                        resolution=nothing)
    return make_forecasts(data, read_timeseries_metadata(metadata_file), mod;
                          resolution=resolution)
end

"""
    make_forecasts(data::SystemData, timeseries_metadata::Vector{TimeseriesFileMetadata};
                   resolution=nothing)

Return a vector of forecasts from a vector of TimeseriesFileMetadata values.

# Arguments
- `data::SystemData`: system
- `timeseries_metadata::Vector{TimeseriesFileMetadata}`: metadata values
- `resolution::{Nothing, Dates.Period}`: skip any forecasts that don't match this resolution
"""
function make_forecasts(
                        data::SystemData,
                        timeseries_metadata::Vector{TimeseriesFileMetadata},
                        mod::Module;
                        resolution=nothing,
                       )
    forecast_infos = ForecastInfos()
    for ts_metadata in timeseries_metadata
        add_forecast_info!(forecast_infos, data, ts_metadata, mod)
    end

    return _make_forecasts(forecast_infos, resolution)
end

"""
    split_forecasts!(data::SystemData,
                     forecasts,
                     interval::Dates.Period,
                     horizon::Int) where T <: Forecast

Replaces system forecasts with a set of forecasts by incrementing through an iterable
set of forecasts by interval and horizon.

"""
function split_forecasts!(
                          data::SystemData,
                          forecasts::FlattenIteratorWrapper{T}, # must be an iterable
                          interval::Dates.Period,
                          horizon::Int,
                         ) where T <: Forecast
    isempty(forecasts) && throw(ArgumentError("Forecasts is empty"))
    split_forecasts = make_forecasts(forecasts, interval, horizon)

    clear_forecasts!(data.forecasts)

    add_forecasts!(data, split_forecasts)

    return
end
 

function _add_forecast!(
                        data::SystemData,
                        component::InfrastructureSystemsType,
                        label::AbstractString,
                        timeseries::TimeSeries.TimeArray,
                        scaling_factor,
                       )
    timeseries = _handle_scaling_factor(timeseries, scaling_factor)
    # TODO: This code path needs to accept a metdata file or parameters telling it which
    # type of forecast to create.
    forecast = Deterministic(component, label, timeseries)
    add_forecast!(data, forecast)
end

function _make_forecasts(forecast_infos::ForecastInfos, resolution)
    forecasts = Vector{Forecast}()

    for forecast_info in forecast_infos.forecasts
        len = length(forecast_info.data)
        @assert len >= 2
        timestamps = TimeSeries.timestamp(forecast_info.data)
        res = timestamps[2] - timestamps[1]
        if !isnothing(resolution) && res != resolution
            @debug "Skip forecast with resolution=$res; doesn't match user=$resolution"
            continue
        end

        timeseries = forecast_info.data[Symbol(get_name(forecast_info.component))]
        timeseries = _handle_scaling_factor(timeseries, forecast_info.scaling_factor)
        forecast_type = get_forecast_type(forecast_info)
        forecast = forecast_type(forecast_info.component, forecast_info.label, timeseries)
        push!(forecasts, forecast)
    end

    return forecasts
end

function add_forecast_info!(infos::ForecastInfos, data::SystemData,
                            metadata::TimeseriesFileMetadata, mod::Module)
    timeseries = _add_forecast_info!(infos, metadata.data_file, metadata.component_name)

    category = _get_category(metadata, mod)
    component = _get_forecast_component(data, category, metadata.component_name)
    if isnothing(component)
        return
    end

    forecast_info = ForecastInfo(metadata, component, timeseries)
    push!(infos.forecasts, forecast_info)
    @debug "Added ForecastInfo" metadata
end

function _get_forecast_component(data::SystemData, category, name)
    if isconcretetype(category)
        component = get_component(category, data, name)
        if isnothing(component)
            throw(DataFormatError(
                "Did not find component for forecast category=$category name=$name"
            ))
        end
    else
        components = get_components_by_name(category, data, name)
        if length(components) == 0
            @warn "Did not find component for forecast category=$category name=$name"
            component = nothing
        elseif length(components) == 1
            component = components[1]
        else
            msg = "Found duplicate names type=$(category) name=$(name)"
            throw(DataFormatError(msg))
        end
    end

    return component
end

"""
Checks that the component exists in data and the UUID's match.
"""
function _validate_forecast(data::SystemData, forecast::Forecast)
    # Validate that each forecast's component is stored in the system.
    comp = forecast.component
    ctype = typeof(comp)
    component = get_component(ctype, data.components, get_name(comp))
    if isnothing(component)
        throw(ArgumentError("no $ctype with name=$(get_name(comp)) is stored"))
    end

    user_uuid = get_uuid(comp)
    ps_uuid = get_uuid(component)
    if user_uuid != ps_uuid
        throw(ArgumentError(
            "forecast component UUID doesn't match, perhaps it was copied?; " *
            "$ctype name=$(get_name(comp)) user=$user_uuid system=$ps_uuid"
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

function convert_forecasts!(
                            data::SystemData,
                            raw::NamedTuple,
                            component_cache::Dict,
                           ) where T <: Forecast
    return convert_type!(data.forecasts, raw.forecasts, component_cache)
end

function compare_values(x::SystemData, y::SystemData)::Bool
    match = true
    for key in keys(x.components.data)
        if !compare_values(x.components.data[key], y.components.data[key])
            @debug "System components do not match"
            match = false
        end
    end

    if !compare_values(x.forecasts.data, y.forecasts.data)
        @debug "System forecasts do not match"
        match = false
    end

    return match
end


# Redirect functions to Components and Forecasts


add_component!(data::SystemData, component; kwargs...) = add_component!(
    data.components, component; kwargs...
)
iterate_components(data::SystemData) = iterate_components(data.components)

remove_component!(::Type{T}, data::SystemData, name) where T = remove_component!(
    T, data.components, name
)
remove_component!(data::SystemData, component) = remove_component!(
    data.components, component
)
remove_components!(::Type{T}, data::SystemData) where T = remove_components!(
    T, data.components
)

get_component(::Type{T}, data::SystemData, args...) where T = get_component(
    T, data.components, args...
)
get_components(::Type{T}, data::SystemData) where T = get_components(T, data.components)
get_components_by_name(::Type{T}, data::SystemData, args...) where T =
    get_components_by_name(T, data.components, args...)

clear_forecasts!(data::SystemData) = clear_forecasts!(data.forecasts)
get_component_forecasts(::Type{T}, data::SystemData, args...) where T =
    get_component_forecasts(T, data.forecasts, args...)
get_forecasts(::Type{T}, data::SystemData, args...) where T = get_forecasts(
    T, data.forecasts, args...
)
iterate_forecasts(data::SystemData) = iterate_forecasts(data.forecasts)
remove_forecast!(data::SystemData, args...) = remove_forecast!(data.forecasts, args...)

get_forecast_initial_times(data::SystemData) = get_forecast_initial_times(data.forecasts)
get_forecasts_horizon(data::SystemData) = get_forecasts_horizon(data.forecasts)
get_forecasts_initial_time(data::SystemData) = get_forecasts_initial_time(data.forecasts)
get_forecasts_interval(data::SystemData) = get_forecasts_interval(data.forecasts)
get_forecasts_resolution(data::SystemData) = get_forecasts_resolution(data.forecasts)
