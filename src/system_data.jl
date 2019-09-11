
struct SystemData{T}
    components::Components
    forecasts::Forecasts
end

function SystemData{T}() where T <: Component
    return SystemData{T}(Components{T}(), Forecasts())
end

"""
    add_forecasts!(data::SystemData, forecasts)

Add forecasts to the system.

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

Add forecasts to the system.

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
    add_forecasts!(data::SystemData, metadata_file::AbstractString; resolution=nothing)

Add forecasts from a metadata file.

# Arguments
- `data::SystemData`: system
- `metadata_file::AbstractString`: path to metadata file
- `resolution::{Nothing, Dates.Period}`: skip any forecasts that don't match this resolution

See [`TimeseriesFileMetadata`](@ref) for description of what the file should contain.
"""
function add_forecasts!(data::SystemData, metadata_file::AbstractString, mod::Module;
                        resolution=nothing)
    add_forecasts!(data, read_timeseries_metadata(metadata_file), mod; resolution=resolution)
end

"""
    add_forecasts!(data::SystemData, timeseries_metadata::Vector{TimeseriesFileMetadata};
                   resolution=nothing)

Add forecasts from a vector of TimeseriesFileMetadata values.

# Arguments
- `data::SystemData`: system
- `timeseries_metadata::Vector{TimeseriesFileMetadata}`: metadata values
- `resolution::{Nothing, Dates.Period}`: skip any forecasts that don't match this resolution
"""
function add_forecasts!(
                        data::SystemData,
                        timeseries_metadata::Vector{TimeseriesFileMetadata},
                        mod::Module;
                        resolution=nothing,
                       )
    forecast_infos = ForecastInfos()
    for ts_metadata in timeseries_metadata
        add_forecast_info!(forecast_infos, data, ts_metadata, mod)
    end

    _add_forecasts!(data, forecast_infos, resolution)
end

"""
    add_forecast!(data::SystemData, filename::AbstractString, component::Component,
                  label::AbstractString, scaling_factor::Union{String, Float64}=1.0)

Add a forecast from a CSV file.

See [`TimeseriesFileMetadata`](@ref) for description of scaling_factor.
"""
function add_forecast!(data::SystemData, filename::AbstractString, component::Component,
                       label::AbstractString, scaling_factor::Union{String, Float64}=1.0)
    component_name = get_name(component)
    # TODO: this only support Deterministic forecasts. If the component_name is in
    # multiple columns then create ScenarioBased instead.
    # Probabilistic would need to accept probabilities vector. This function should take a
    # metadata file instead of single CSV file.
    ts = read_timeseries(filename, component_name)
    timeseries = ts[Symbol(component_name)]
    _add_forecast!(data, component, label, timeseries, scaling_factor)
end

"""
    add_forecast!(data::SystemData, ta::TimeSeries.TimeArray, component::Component,
                  label::AbstractString, scaling_factor::Union{String, Float64}=1.0)

Add a forecast to a system from a TimeSeries.TimeArray.

See [`TimeseriesFileMetadata`](@ref) for description of scaling_factor.
"""
function add_forecast!(data::SystemData, ta::TimeSeries.TimeArray, component::Component,
                       label::AbstractString, scaling_factor::Union{String, Float64}=1.0)
    timeseries = ta[Symbol(get_name(component))]
    _add_forecast!(data, component, label, timeseries, scaling_factor)
end

"""
    add_forecast!(sys::System, df::DataFrames.DataFrame, component::Component,
                  label::AbstractString, scaling_factor::Union{String, Float64}=1.0)

Add a forecast to a system from a DataFrames.DataFrame.

See [`TimeseriesFileMetadata`](@ref) for description of scaling_factor.
"""
function add_forecast!(data::SystemData, df::DataFrames.DataFrame, component::Component,
                       label::AbstractString, scaling_factor::Union{String, Float64}=1.0;
                       timestamp=:timestamp)
    timeseries = TimeSeries.TimeArray(df; timestamp=timestamp)
    add_forecast!(data, timeseries, component, label, scaling_factor)
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
 

function _add_forecast!(data::SystemData, component::Component, label::AbstractString,
                        timeseries::TimeSeries.TimeArray, scaling_factor)
    timeseries = _handle_scaling_factor(timeseries, scaling_factor)
    # TODO DT: shouldn't hard-code to Deterministic
    forecast = Deterministic(component, label, timeseries)
    add_forecast!(data, forecast)
end

function _add_forecasts!(data::SystemData, forecast_infos::ForecastInfos, resolution)
    for forecast in forecast_infos.forecasts
        len = length(forecast.data)
        @assert len >= 2
        timestamps = TimeSeries.timestamp(forecast.data)
        res = timestamps[2] - timestamps[1]
        if !isnothing(resolution) && res != resolution
            @debug "Skip forecast with resolution=$res; doesn't match user=$resolution"
            continue
        end

        # TODO: needs special handling in PowerSystems
        #if forecast.component isa LoadZones
        #    uuids = Set([get_uuid(x) for x in forecast.component.buses])
        #    forecast_components = [load for load in get_components(ElectricLoad, data)
        #                           if get_bus(load) |> get_uuid in uuids]
        #else
        #    forecast_components = [forecast.component]
        #end

        forecast_components = [forecast.component]
        timeseries = forecast.data[Symbol(get_name(forecast.component))]
        timeseries = _handle_scaling_factor(timeseries, forecast.scaling_factor)
        forecasts = [Deterministic(x, forecast.label, timeseries)
                     for x in forecast_components]
        add_forecasts!(data, forecasts)
    end
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

""" Checks that the component exists in and the UUID's match"""
function _validate_forecast(data::SystemData, forecast::T) where T <: Forecast
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

function JSON2.read(io::IO, ::Type{SystemData})
    error("exit in SystemData IS")
end

function get_component_types_raw(::Type{SystemData}, raw::NamedTuple)
    return get_component_types_raw(Components, raw.components)
end

function get_components_raw(::Type{SystemData}, ::Type{T}, raw::NamedTuple) where T <: InfrastructureSystemsType
    return get_components_raw(Components, T, raw.components)
end

function convert_type!(
                       data::SystemData,
                       raw::NamedTuple,
                       component_cache::Dict,
                      ) where T <: Forecast
    return convert_type!(data.forecasts, raw.forecasts, component_cache)
end

function Base.summary(io::IO, data::SystemData)
    Base.summary(io, data.components)
    println(io, "\n")
    Base.summary(io, data.forecasts)
end

iterate_components(data::SystemData) = iterate_components(data.components)
add_component!(data::SystemData, component; kwargs...) = add_component!(data.components, component; kwargs...)

remove_components!(::Type{T}, data::SystemData) where T = remove_components!(T, data.components)
remove_component!(data::SystemData, component) = remove_component!(data.components, component)
remove_component!(::Type{T}, data::SystemData, name) where T = remove_component!(T, data.components, name)

get_component(::Type{T}, data::SystemData, args...) where T = get_component(T, data.components, args...)
get_components(::Type{T}, data::SystemData) where T = get_components(T, data.components)
get_components_by_name(::Type{T}, data::SystemData, args...) where T = get_components_by_name(T, data.components, args...)
get_component_forecasts(::Type{T}, data::SystemData, args...) where T = get_component_forecasts(T, data.forecasts, args...)

add_forecasts!(data::SystemData, metadata::AbstractString; kwargs...) = add_forecasts!(data.forecasts, metadata; kwargs...)
add_forecasts!(data::SystemData, metadata::Vector{TimeseriesFileMetadata}; kwargs...) = add_forecasts!(data.forecasts, metadata; kwargs...)
get_forecasts(::Type{T}, data::SystemData, args...) where T = get_forecasts(T, data.forecasts, args...)
iterate_forecasts(data::SystemData) = iterate_forecasts(data.forecasts)
remove_forecast!(data::SystemData, args...) = remove_forecast!(data.forecasts, args...)
clear_forecasts!(data::SystemData) = clear_forecasts!(data.forecasts)

get_forecast_initial_times(data::SystemData) = get_forecast_initial_times(data.forecasts)
get_forecasts_horizon(data::SystemData) = get_forecasts_horizon(data.forecasts)
get_forecasts_initial_time(data::SystemData) = get_forecasts_initial_time(data.forecasts)
get_forecasts_interval(data::SystemData) = get_forecasts_interval(data.forecasts)
get_forecasts_resolution(data::SystemData) = get_forecasts_resolution(data.forecasts)
