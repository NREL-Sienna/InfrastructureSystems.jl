
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
    num_components = get_num_components(components)
    println(io, "Components")
    println(io, "==========")
    println(io, "Num components: $num_components")
    if num_components > 0
        println(io)
        show_components_table(io, components, backend = :auto)
    end
end

function Base.show(io::IO, ::MIME"text/html", components::Components)
    num_components = get_num_components(components)
    println(io, "<h2>Components</h2>")
    println(io, "<p><b>Num components</b>: $num_components</p>")
    if num_components > 0
        show_components_table(io, components, backend = :html)
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
    return "$(typeof(time_series)) time_series ($(length(time_series)))"
end

function Base.summary(time_series::TimeSeriesMetadata)
    return "$(typeof(time_series)) time_series"
end

function Base.show(io::IO, data::SystemData)
    show(io, data.components)
    println(io, "\n")
    return show(io, data.time_series_params)
end

function Base.show(io::IO, ::MIME"text/plain", data::SystemData)
    show(io, MIME"text/plain"(), data.components)
    println(io, "\n")
    show_time_series_data(io, data, backend = :auto)
    show(io, data.time_series_params)
end

function Base.show(io::IO, ::MIME"text/html", data::SystemData)
    show(io, MIME"text/html"(), data.components)
    println(io, "\n")
    show_time_series_data(io, data, backend = :html)
    show(io, data.time_series_params)
end

function show_time_series_data(io::IO, data::SystemData; kwargs...)
    component_count, ts_count, forecast_count = get_time_series_counts(data)
    res = get_time_series_resolution(data)
    res = res <= Dates.Minute(1) ? Dates.Second(res) : Dates.Minute(res)

    header = ["Property", "Value"]
    table = [
        "Components with time series data" string(component_count)
        "Total StaticTimeSeries" string(ts_count)
        "Total Forecasts" string(forecast_count)
        "Resolution" string(res)
    ]
    if component_count == 0
        return
    end

    if forecast_count > 0
        initial_times = get_forecast_initial_times(data)
        table2 = [
            "First initial time" string(first(initial_times))
            "Last initial time" string(last(initial_times))
            "Horizon" string(get_forecast_horizon(data))
            "Interval" string(Dates.Minute(get_forecast_interval(data)))
            "Forecast window count" string(get_forecast_window_count(data))
        ]
        table = vcat(table, table2)
    end

    PrettyTables.pretty_table(
        io,
        table;
        header = header,
        title = "Time Series Summary",
        alignment = :l,
        kwargs...,
    )
    return
end

function Base.summary(ist::InfrastructureSystemsComponent)
    # All InfrastructureSystemsComponent subtypes are supposed to implement get_name.
    # Some don't.  They need to override this function.
    return "$(get_name(ist)) ($(typeof(ist)))"
end

function Base.show(io::IO, ::MIME"text/plain", system_units::SystemUnitsSettings)
    print(io, summary(system_units), ":")
    for name in fieldnames(typeof(system_units))
        val = getfield(system_units, name)
        print(io, "\n      ", name, ": ", val)
    end
end

function Base.show(io::IO, ::MIME"text/plain", ist::InfrastructureSystemsComponent)
    print(io, summary(ist), ":")
    for (name, field_type) in zip(fieldnames(typeof(ist)), fieldtypes(typeof(ist)))
        obj = getfield(ist, name)
        if obj isa InfrastructureSystemsInternal
            continue
        elseif obj isa TimeSeriesContainer || obj isa InfrastructureSystemsType
            val = summary(getfield(ist, name))
        elseif obj isa Vector{<:InfrastructureSystemsComponent}
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

function Base.show(io::IO, ist::InfrastructureSystemsComponent)
    print(io, string(nameof(typeof(ist))), "(")
    is_first = true
    for (name, field_type) in zip(fieldnames(typeof(ist)), fieldtypes(typeof(ist)))
        if field_type <: TimeSeriesContainer || field_type <: InfrastructureSystemsInternal
            continue
        else
            val = getfield(ist, name)
        end
        if is_first
            is_first = false
        else
            print(io, ", ")
        end
        print(io, val)
    end
    print(io, ")")
    return
end

function Base.show(io::IO, ::MIME"text/plain", it::FlattenIteratorWrapper)
    println(io, "$(eltype(it)) Counts: ")
    for (ctype, count) in _get_type_counts(it)
        println(io, "$ctype: $count")
    end
end

function _get_type_counts(it::FlattenIteratorWrapper)
    data = SortedDict()
    for component in it
        ctype = string(typeof(component))
        if !haskey(data, ctype)
            data[ctype] = 1
        else
            data[ctype] += 1
        end
    end

    return data
end

function show_components_table(io::IO, components::Components; kwargs...)
    header = ["Type", "Count", "Has Static Time Series", "Has Forecasts"]
    data = Array{Any, 2}(undef, length(components.data), length(header))

    type_names = [(strip_module_name(string(x)), x) for x in keys(components.data)]
    sort!(type_names, by = x -> x[1])
    for (i, (type_name, type)) in enumerate(type_names)
        vals = components.data[type]
        has_sts = false
        has_forecasts = false
        for val in values(vals)
            if has_time_series(val, StaticTimeSeries)
                has_sts = true
            end
            if has_time_series(val, Forecast)
                has_forecasts = true
            end
            if has_sts && has_forecasts
                break
            end
        end
        data[i, 1] = type_name
        data[i, 2] = length(vals)
        data[i, 3] = has_sts
        data[i, 4] = has_forecasts
    end

    PrettyTables.pretty_table(io, data; header = header, alignment = :l, kwargs...)
    return
end

function show_components(
    io::IO,
    components::Components,
    component_type::Type{<:InfrastructureSystemsComponent},
    additional_columns::Union{Dict, Vector} = [];
    kwargs...,
)
    if !isconcretetype(component_type)
        error("$component_type must be a concrete type")
    end

    title = string(strip_module_name(component_type))
    header = ["name"]
    has_available = false
    if :available in fieldnames(component_type)
        push!(header, "available")
        has_available = true
    end

    if additional_columns isa Dict
        columns = sort!(collect(keys(additional_columns)))
    else
        columns = additional_columns
    end

    for column in columns
        push!(header, string(column))
    end

    comps = get_components(component_type, components)
    data = Array{Any, 2}(undef, length(comps), length(header))
    for (i, component) in enumerate(comps)
        data[i, 1] = get_name(component)
        j = 2
        if has_available
            data[i, 2] = getproperty(component, :available)
            j += 1
        end

        if additional_columns isa Dict
            for column in columns
                data[i, j] = additional_columns[column](component)
                j += 1
            end
        else
            for column in additional_columns
                getter_name = Symbol("get_$column")
                parent = parentmodule(component_type)
                # This logic enables application of system units in PowerSystems through
                # its getter functions.
                val = getproperty(component, column)
                if val isa TimeSeriesContainer ||
                   val isa InfrastructureSystemsType ||
                   val isa Vector{<:InfrastructureSystemsComponent}
                    val = summary(val)
                elseif hasproperty(parent, getter_name)
                    getter_func = getproperty(parent, getter_name)
                    val = getter_func(component)
                end
                data[i, j] = val
                j += 1
            end
        end
    end

    PrettyTables.pretty_table(
        io,
        data;
        header = header,
        title = title,
        alignment = :l,
        kwargs...,
    )
    return
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
