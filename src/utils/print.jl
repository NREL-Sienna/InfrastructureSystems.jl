
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
    return "$(typeof(forecast)) forecast"
end

function Base.summary(forecast::ForecastInternal)
    return "$(typeof(forecast)) forecast"
end

function Base.show(io::IO, data::SystemData)
    show(io, data.components)
    println(io, "\n")
    show(io, data.forecast_metadata)
end

function Base.show(io::IO, ::MIME"text/plain", data::SystemData)
    show(io, MIME"text/plain"(), data.components)
    println(io, "\n")

    println(io, "Forecasts")
    println(io, "=========")
    println(io, "Resolution: $(Dates.Minute(get_forecasts_resolution(data)))")
    println(io, "Horizon: $(get_forecasts_horizon(data))")
    initial_times = [string(x) for x in get_forecast_initial_times(data)]
    println(io, "Initial Times: $(join(initial_times, ", "))")
    println(io, "Interval: $(get_forecasts_interval(data))")
    component_count, forecast_count = get_forecast_counts(data)
    println(io, "Components with Forecasts: $component_count")
    println(io, "Total Forecasts: $forecast_count")
end

function Base.show(io::IO, ::MIME"text/html", data::SystemData)
    show(io, MIME"text/html"(), data.components)
    println(io, "\n")

    println(io, "<h2>Forecasts</h2>")
    println(io, "<p><b>Resolution</b>: $(Dates.Minute(get_forecasts_resolution(data)))</p>")
    println(io, "<p><b>Horizon</b>: $(get_forecasts_horizon(data))</p>")
    initial_times = [string(x) for x in get_forecast_initial_times(data)]
    println(io, "<p><b>Initial Times</b>: $(join(initial_times, ", "))</p>")
    println(io, "<p><b>Interval</b>: $(get_forecasts_interval(data))</p>")
    component_count, forecast_count = get_forecast_counts(data)
    println(io, "<p><b>Components with Forecasts</b>: $component_count</p>")
    println(io, "<p><b>Total Forecasts</b>: $forecast_count</p>")
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
        type_str = strip_module_name(string(subtype))
        counts[type_str] = length(values)
        parents = [strip_module_name(string(x)) for x in supertypes(subtype)]
        row = (ConcreteType=type_str,
               SuperTypes=join(parents, " <: "),
               Count=length(values))
        push!(rows, row)
    end

    sort!(rows, by = x -> x.ConcreteType)

    return DataFrames.DataFrame(rows)
end

function Base.show(io::IO, ::MIME"text/plain", period::Union{Dates.TimePeriod, Dates.DatePeriod})
    total = convert_compound_period(period)
    println(io, "$total")
end

function Base.show(io::IO, ::MIME"text/html", period::Union{Dates.TimePeriod, Dates.DatePeriod})
    total = convert_compound_period(period)
    println(io, "<p>$total</p>")
end

## This function takes in a time period or date period and returns a compound period
function convert_compound_period(period::Union{Dates.TimePeriod, Dates.DatePeriod})
    period = time_period_conversion(period)

    milli_weeks = period - (period % Dates.Millisecond(604800000))
    weeks = convert(Dates.Week, milli_weeks)
    period -= milli_weeks

    milli_days = period - (period % Dates.Millisecond(86400000))
    days = convert(Dates.Day, milli_days)
    period -= milli_days

    milli_hours = period - (period % Dates.Millisecond(3600000))
    hours = convert(Dates.Hour, milli_hours)
    period -= milli_hours

    milli_minutes = period - (period % Dates.Millisecond(60000))
    minutes = convert(Dates.Minute, milli_minutes)
    period -= milli_minutes

    seconds = period - (period % Dates.Millisecond(1000)) # finding the seconds
    seconds = convert(Dates.Second, seconds)
    remainder = period % Dates.Millisecond(1000) #finding the remainding milliseconds
    total = weeks + days + hours + minutes + seconds + remainder
    return total
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

            type_str = strip_module_name(string(key.forecast_type))
            counts[type_str] = length(values)
            parents = [strip_module_name(string(x)) for x in supertypes(key.forecast_type)]
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
