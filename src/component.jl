function add_forecast!(
                       component::InfrastructureSystemsType,
                       forecast::T,
                      ) where T <: ForecastInternal
    add_forecast!(_get_forecast_container(component), forecast)
    @debug "Added $forecast to $(typeof(component)) $(component.name) num_forecasts=$(length(component._forecasts.data))."
end

"""
    remove_forecast_internal!(
                              ::Type{T},
                              component::InfrastructureSystemsType,
                              initial_time::Dates.DateTime,
                              label::AbstractString,
                             ) where T <: ForecastInternal

Removes the metadata for a forecast.
The caller must also remove the actual time series data.
"""
function remove_forecast_internal!(
                                   ::Type{T},
                                   component::InfrastructureSystemsType,
                                   initial_time::Dates.DateTime,
                                   label::AbstractString,
                                  ) where T <: ForecastInternal
    remove_forecast!(T, _get_forecast_container(component), initial_time, label)
    @debug "Removed forecast from $component:  $initial_time $label."
end

function clear_forecasts!(component::InfrastructureSystemsType)
    clear_forecasts!(_get_forecast_container(component))
    @debug "Cleared forecasts in $component."
end

function get_forecast(
                      ::Type{T},
                      component::InfrastructureSystemsType,
                      initial_time::Dates.DateTime,
                      label::AbstractString,
                     ) where T <: ForecastInternal
    return get_forecast(T, _get_forecast_container(component), initial_time, label)
end

function get_forecast(
                      ::Type{T},
                      component::InfrastructureSystemsType,
                      initial_time::Dates.DateTime,
                      sys_resolution::Dates.Period,
                      sys_horizon::Int,
                      label::AbstractString,
                      horizon::Int,
                     ) where T <: ForecastInternal
    end_time = initial_time + sys_resolution * horizon
    @debug "Requested forecast" initial_time horizon
    initial_times = get_forecast_initial_times(T, _get_forecast_container(component), label)
    for it in initial_times
        # Return the forecast for this time array if it encompasses the requested range and
        # one of its data points is the requested initial_time.
        if it <= initial_time && (end_time <= (it + sys_resolution * sys_horizon)) &&
                ((initial_time - it) % Dates.Millisecond(sys_resolution) == Dates.Second(0))
            return get_forecast(T, _get_forecast_container(component), it, label)
        end
    end

    throw(ArgumentError("did not find a forecast matching the requested parameters"))
end

function _get_forecast_container(component::InfrastructureSystemsType)
    # TODO: The get__forecasts methods in PowerSystems need to be IS.get__forecasts.
    #container = get__forecasts(component)
    if :_forecasts in fieldnames(typeof(component))
        container = component._forecasts
    else
        container = nothing
    end
    return container
end

function has_forecasts(component::InfrastructureSystemsType)
    return !isnothing(_get_forecast_container(component))
end

function get_forecast_initial_times(
                                    ::Type{T},
                                    component::InfrastructureSystemsType,
                                   ) where T <: Forecast
    if !has_forecasts(component)
        throw(ArgumentError("$(typeof(component)) does not have forecasts"))
    end
    return get_forecast_initial_times(forecast_external_to_internal(T),
                                      _get_forecast_container(component))
end

function get_forecast_initial_times(
                                    ::Type{T},
                                    component::InfrastructureSystemsType,
                                    label::AbstractString,
                                   ) where T <: Forecast
    if !has_forecasts(component)
        throw(ArgumentError("$(typeof(component)) does not have forecasts"))
    end
    return get_forecast_initial_times(forecast_external_to_internal(T),
                                      _get_forecast_container(component),
                                      label)
end

function get_forecast_initial_times!(
                                     initial_times::Set{Dates.DateTime},
                                     component::InfrastructureSystemsType,
                                    )
    if !has_forecasts(component)
        throw(ArgumentError("$(typeof(component)) does not have forecasts"))
    end

    get_forecast_initial_times!(initial_times, _get_forecast_container(component))
end

function get_forecast_keys(component::InfrastructureSystemsType)
    return keys(_get_forecast_container(component).data)
end

function get_forecast_labels(
                             ::Type{T},
                             component::InfrastructureSystemsType,
                             initial_time::Dates.DateTime,
                            ) where T <: Forecast
    return get_forecast_labels(forecast_external_to_internal(T),
                               _get_forecast_container(component),
                               initial_time)
end

function get_time_series_uuids(component::InfrastructureSystemsType)
    container = _get_forecast_container(component)

    return [(get_time_series_uuid(container.data[key]), key.label)
             for key in get_forecast_keys(component)]
end

function iterate_forecasts(component::InfrastructureSystemsType)
    container = _get_forecast_container(component)
    forecast_keys = sort!(collect(keys(container.data)), by = x -> x.initial_time)

    Channel() do channel
        for key in forecast_keys
            put!(channel, container.data[key])
        end
    end
end

function validate_forecast_consistency(component::InfrastructureSystemsType)
    # Initial times for each label must be identical.
    initial_times = Dict{String, Vector{Dates.DateTime}}()
    for key in keys(_get_forecast_container(component).data)
        if !haskey(initial_times, key.label)
            initial_times[key.label] = Vector{Dates.DateTime}()
        end
        push!(initial_times[key.label], key.initial_time)
    end

    if isempty(initial_times)
        return true
    end

    base_its = nothing
    for (label, its) in initial_times
        sort!(its)
        if isnothing(base_its)
            base_its = its
        elseif its != base_its
            @error "initial times don't match" base_its, its
            return false
        end
    end

    return true
end
