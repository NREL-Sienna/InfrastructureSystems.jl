
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

function Base.summary(container::TimeSeriesContainer)
    return "$(typeof(container)): $(length(container))"
end

function Base.show(io::IO, ::MIME"text/plain", container::TimeSeriesContainer)
    println(io, summary(container))
    for key in keys(container.data)
        println(io, "$(key.time_series_type): name=$(key.name)")
    end
end

function Base.summary(time_series::TimeSeriesData)
    return "$(typeof(time_series)) time_series ($length(time_series))"
end

function Base.summary(time_series::TimeSeriesMetadata)
    return "$(typeof(time_series)) time_series"
end

function Base.show(io::IO, data::SystemData)
    show(io, data.components)
    println(io, "\n")
    show(io, data.time_series_params)
end

function Base.show(io::IO, ::MIME"text/plain", data::SystemData)
    component_count, ts_count, forecast_count = get_time_series_counts(data)
    show(io, MIME"text/plain"(), data.components)
    println(io, "\n")

    println(io, "TimeSeriesContainer")
    println(io, "===================")
    println(io, "Components with time series data: $component_count")
    println(io, "Total StaticTimeSeries: $ts_count")
    println(io, "Total Forecasts: $forecast_count")
    if component_count == 0
        return
    end

    res = get_time_series_resolution(data)
    res = res <= Dates.Minute(1) ? Dates.Second(res) : Dates.Minute(res)
    println(io, "Resolution: $res")
    if forecast_count > 0
        println(io, "Forecast window count: $(get_forecast_window_count(data))")
        println(io, "Horizon: $(get_forecast_horizon(data))")
        println(io, "Interval: $(Dates.Minute(get_forecast_interval(data)))")
        println(io, "Total Period: $(Dates.Hour(get_forecast_total_period(data)))")
    end
end

function Base.show(io::IO, ::MIME"text/html", data::SystemData)
    show(io, MIME"text/html"(), data.components)
    println(io, "\n")

    component_count, ts_count, forecast_count = get_time_series_counts(data)
    println(io, "<h2>TimeSeriesContainer</h2>")
    println(io, "<p><b>Components with time series data</b>: $component_count</p>")
    println(io, "<p><b>Total StaticTimeSeries</b>: $ts_count</p>")
    println(io, "<p><b>Total Forecasts</b>: $forecast_count</p>")

    res = get_time_series_resolution(data)
    res = res <= Dates.Minute(1) ? Dates.Second(res) : Dates.Minute(res)
    println(io, "<p><b>Resolution</b>: $(res)</p>")
    if forecast_count > 0
        window_count = get_forecast_window_count(data)
        period = Dates.Hour(get_forecast_total_period(data))
        println(io, "<p><b>Forecast window count</b>: $(window_count)</p>")
        println(io, "<p><b>Horizon</b>: $(get_forecast_horizon(data))</p>")
        println(io, "<p><b>Interval</b>: $(Dates.Minute(get_forecast_interval(data)))</p>")
        println(io, "<p><b>Total Period</b>: $period</p>")
    end
end

function Base.summary(ist::InfrastructureSystemsComponent)
    # All InfrastructureSystemsComponent subtypes are supposed to implement get_name.
    # Some don't.  They need to override this function.
    return "$(get_name(ist)) ($(typeof(ist)))"
end

function Base.show(io::IO, ::MIME"text/plain", ist::InfrastructureSystemsComponent)
    print(io, summary(ist), ":")
    for (name, field_type) in zip(fieldnames(typeof(ist)), fieldtypes(typeof(ist)))
        if field_type <: InfrastructureSystemsInternal
            continue
        elseif field_type <: TimeSeriesContainer || field_type <: InfrastructureSystemsType
            val = summary(getfield(ist, name))
        elseif field_type <: Vector{<:InfrastructureSystemsComponent}
            val = summary(getfield(ist, name))
        else
            val = getfield(ist, name)
        end
        # Not allowed to print `nothing`
        if isnothing(val)
            val = "nothing"
        end
        print(io, "\n   ", name, ": ", val)
    end
end

function Base.show(
    io::IO,
    ::MIME"text/plain",
    ists::Vector{<:InfrastructureSystemsComponent},
)
    println(io, summary(ists))
    for i in 1:length(ists)
        if isassigned(ists, i)
            println(io, "$(summary(ists[i]))")
        else
            println(io, Base.undef_ref_str)
        end
    end
end

function create_components_df(components::Components)
    counts = Dict{String, Int}()
    rows = []

    for (subtype, values) in components.data
        type_str = strip_module_name(string(subtype))
        counts[type_str] = length(values)
        parents = [strip_module_name(string(x)) for x in supertypes(subtype)]
        row = (
            ConcreteType = type_str,
            SuperTypes = join(parents, " <: "),
            Count = length(values),
        )
        push!(rows, row)
    end

    sort!(rows, by = x -> x.ConcreteType)

    return DataFrames.DataFrame(rows)
end

function Base.show(
    io::IO,
    ::MIME"text/plain",
    period::Union{Dates.TimePeriod, Dates.DatePeriod},
)
    total = convert_compound_period(period)
    println(io, "$total")
end

function Base.show(
    io::IO,
    ::MIME"text/html",
    period::Union{Dates.TimePeriod, Dates.DatePeriod},
)
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
