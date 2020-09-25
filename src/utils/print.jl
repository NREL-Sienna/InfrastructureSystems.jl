
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
    show(io, MIME"text/plain"(), data.components)
    println(io, "\n")

    println(io, "TimeSeriesContainer")
    println(io, "=========")
    res = get_time_series_resolution(data)
    res = res <= Dates.Minute(1) ? Dates.Second(res) : Dates.Minute(res)
    println(io, "Resolution: $(res)")
    println(io, "Horizon: $(get_time_series_horizon(data))")
    initial_times = [string(x) for x in get_time_series_initial_times(data)]
    println(io, "Initial Times: $(join(initial_times, ", "))")
    println(io, "Interval: $(get_time_series_interval(data))")
    component_count, time_series_count = get_time_series_counts(data)
    println(io, "Components with TimeSeriesContainer: $component_count")
    println(io, "Total TimeSeriesContainer: $time_series_count")
end

function Base.show(io::IO, ::MIME"text/html", data::SystemData)
    show(io, MIME"text/html"(), data.components)
    println(io, "\n")

    res = get_time_series_resolution(data)
    res = res <= Dates.Minute(1) ? Dates.Second(res) : Dates.Minute(res)
    println(io, "<h2>TimeSeriesContainer</h2>")
    println(io, "<p><b>Resolution</b>: $(res)</p>")
    println(io, "<p><b>Horizon</b>: $(get_time_series_horizon(data))</p>")
    initial_times = [string(x) for x in get_time_series_initial_times(data)]
    println(io, "<p><b>Initial Times</b>: $(join(initial_times, ", "))</p>")
    println(io, "<p><b>Interval</b>: $(get_time_series_interval(data))</p>")
    component_count, time_series_count = get_time_series_counts(data)
    println(io, "<p><b>Components with TimeSeriesContainer</b>: $component_count</p>")
    println(io, "<p><b>Total TimeSeriesContainer</b>: $time_series_count</p>")
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

function create_time_series_df(container::TimeSeriesContainer)
    initial_times = _get_time_series_initial_times(container.data)
    dfs = Vector{DataFrames.DataFrame}()

    for (i, initial_time) in enumerate(initial_times)
        if i > MAX_SHOW_FORECAST_INITIAL_TIMES
            break
        end
        counts = Dict{String, Int}()
        rows = []

        for (key, values) in container.data
            if key.initial_time != initial_time
                continue
            end

            type_str = strip_module_name(string(key.time_series_type))
            counts[type_str] = length(values)
            parents =
                [strip_module_name(string(x)) for x in supertypes(key.time_series_type)]
            row = (
                ConcreteType = type_str,
                SuperTypes = join(parents, " <: "),
                Count = length(values),
            )
            push!(rows, row)
        end

        sort!(rows, by = x -> x.ConcreteType)

        df = DataFrames.DataFrame(rows)
        push!(dfs, df)
    end

    return initial_times, dfs
end
