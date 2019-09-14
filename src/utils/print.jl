
const MAX_SHOW_COMPONENTS = 10
const MAX_SHOW_FORECASTS = 10
const MAX_SHOW_FORECAST_INITIAL_TIMES = 1


function Base.summary(components::Components)
    return "$(typeof(components)): $(get_num_components(components))"
end

function Base.show(io::IO, components::Components)
    i = 1
    for component in iterate_components(components)
        if i <= MAX_SHOW_COMPONENTS
            show(io, component)
            println(io)
        end
        i += 1
    end

    if i > MAX_SHOW_COMPONENTS
        num = i - MAX_SHOW_COMPONENTS
        println(io, "\n***Omitted $num components***\n")
    end
end

function Base.show(io::IO, ::MIME"text/plain", components::Components)
    df = create_components_df(components)
    println(io, "Components")
    println(io, "==========")
    println(io, "Num components: $(get_num_components(components))\n")
    show(io, df)
end

function Base.show(io::IO, ::MIME"text/html", components::Components)
    df = create_components_df(components)
    println(io, "<h2>Components</h2>")
    println(io, "<p><b>Num components</b>: $(get_num_components(components))</p>")
    withenv("LINES" => 100, "COLUMNS" => 200) do
        show(io, MIME"text/html"(), df)
    end
end

function Base.summary(forecast::Forecast)
    component = get_component(forecast)
    component_name = get_name(component)
    return "$(typeof(forecast)) forecast (component=$component_name)"
end

function Base.summary(forecasts::Forecasts)
    return "$(typeof(forecasts)): $(get_num_forecasts(forecasts))"
end

function Base.show(io::IO, forecasts::Forecasts)
    i = 1
    for forecast in iterate_forecasts(forecasts)
        if i <= MAX_SHOW_FORECASTS
            show(io, forecast)
            println(io)
        end
        i += 1
    end

    if i > MAX_SHOW_FORECASTS
        num = i - MAX_SHOW_FORECASTS
        println(io, "\n***Omitted $num forecasts***\n")
    end
end

function Base.show(io::IO, ::MIME"text/plain", forecasts::Forecasts)
    initial_times, dfs = create_forecasts_df(forecasts)
    println(io, "Forecasts")
    println(io, "=========")
    println(io, "Resolution: $(forecasts.resolution)")
    println(io, "Horizon: $(forecasts.horizon)")
    println(io, "Interval: $(forecasts.interval)")
    println(io, "Num initial times: $(length(initial_times))")
    println(io, "Num forecasts: $(get_num_forecasts(forecasts))\n")
    println(io, "---------------------------------")

    for (initial_time, df) in zip(initial_times, dfs)
        println(io, "Initial Time: $initial_time")
        println(io, "---------------------------------")
        show(io, df)
    end

    if length(initial_times) > MAX_SHOW_FORECAST_INITIAL_TIMES
        num = length(initial_times) - MAX_SHOW_FORECAST_INITIAL_TIMES
        println(io, "\n\n***Omitted tables for $num initial times***\n")
    end
end

function Base.show(io::IO, ::MIME"text/html", forecasts::Forecasts)
    initial_times, dfs = create_forecasts_df(forecasts)
    println(io, "<h2>Forecasts</h2>")
    println(io, "<p><b>Resolution</b>: $(forecasts.resolution)</p>")
    println(io, "<p><b>Horizon</b>: $(forecasts.horizon)</p>")
    println(io, "<p><b>Interval</b>: $(forecasts.interval)</p>")
    println(io, "<p><b>Num initial times</b>: $(length(initial_times))</p>")
    println(io, "<p><b>Num forecasts</b>: $(get_num_forecasts(forecasts))</p>")

    for (initial_time, df) in zip(initial_times, dfs)
        println(io, "<p><b>Initial Time</b>: $initial_time</p>")
        withenv("LINES" => 100, "COLUMNS" => 200) do
            show(io, MIME"text/html"(), df)
        end
    end

    if length(initial_times) > MAX_SHOW_FORECAST_INITIAL_TIMES
        num = length(initial_times) - MAX_SHOW_FORECAST_INITIAL_TIMES
        println(io, "<p><b>Omitted tables for $num initial times</b></p>")
    end
end

function Base.show(io::IO, data::SystemData)
    show(io, data.components)
    println(io, "\n")
    show(io, data.forecasts)
end

function Base.show(io::IO, ::MIME"text/plain", data::SystemData)
    show(io, MIME"text/plain"(), data.components)
    println(io, "\n")
    show(io, MIME"text/plain"(), data.forecasts)
end

function Base.show(io::IO, ::MIME"text/html", data::SystemData)
    show(io, MIME"text/html"(), data.components)
    println(io, "\n")
    show(io, MIME"text/html"(), data.forecasts)
end

function Base.summary(ist::InfrastructureSystemsType)
    # All InfrastructureSystemsType subtypes are supposed to implement get_name.
    # Some don't.  They need to override this function.
    return "$(get_name(ist)) ($(typeof(ist)))"
end

function Base.show(io::IO, ::MIME"text/plain", ist::InfrastructureSystemsType)
    print(io, summary(ist), ":")
    for name in fieldnames(typeof(ist))
        name == :internal && continue
        val = getfield(ist, name)
        # Not allowed to print `nothing`
        if isnothing(val)
            val = "nothing"
        end
        print(io, "\n   ", name, ": ", val)
    end
end

function create_components_df(components::Components)
    counts = Dict{String, Int}()
    rows = []

    for (subtype, values) in components.data
        type_str = strip_module_names(string(subtype))
        counts[type_str] = length(values)
        parents = [strip_module_names(string(x)) for x in supertypes(subtype)]
        row = (ConcreteType=type_str,
               SuperTypes=join(parents, " <: "),
               Count=length(values))
        push!(rows, row)
    end

    sort!(rows, by = x -> x.ConcreteType)

    return DataFrames.DataFrame(rows)
end

function create_forecasts_df(forecasts::Forecasts)
    initial_times = _get_forecast_initial_times(forecasts.data)
    dfs = Vector{DataFrames.DataFrame}()

    for (i, initial_time) in enumerate(initial_times)
        if i > MAX_SHOW_FORECAST_INITIAL_TIMES
            break
        end
        counts = Dict{String, Int}()
        rows = []

        for (key, values) in forecasts.data
            if key.initial_time != initial_time
                continue
            end

            type_str = strip_module_names(string(key.forecast_type))
            counts[type_str] = length(values)
            parents = [strip_module_names(string(x)) for x in supertypes(key.forecast_type)]
            row = (ConcreteType=type_str,
                   SuperTypes=join(parents, " <: "),
                   Count=length(values))
            push!(rows, row)
        end

        sort!(rows, by = x -> x.ConcreteType)

        df = DataFrames.DataFrame(rows)
        push!(dfs, df)
    end

    return initial_times, dfs
end


