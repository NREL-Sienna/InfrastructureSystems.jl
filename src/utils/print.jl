
const MAX_SHOW_COMPONENTS = 10
const MAX_SHOW_FORECASTS = 10
const MAX_SHOW_FORECAST_INITIAL_TIMES = 1

function Base.summary(container::InfrastructureSystemsContainer)
    return "$(typeof(container)): $(get_num_members(container))"
end

function Base.show(io::IO, container::InfrastructureSystemsContainer)
    i = 1
    for component in iterate_container(container)
        if i <= MAX_SHOW_COMPONENTS
            show(io, component)
            println(io)
        end
        i += 1
    end

    if i > MAX_SHOW_COMPONENTS
        num = i - MAX_SHOW_COMPONENTS
        println(io, "\n***Omitted $num $(get_display_string(container))***\n")
    end
end

function Base.show(io::IO, ::MIME"text/plain", container::InfrastructureSystemsContainer)
    num_members = get_num_members(container)
    title = get_display_string(container)
    member_str = get_member_string(container)
    println(io, title)
    println(io, "="^length(title))
    println(io, "Num $member_str: $num_members")
    if num_members > 0
        println(io)
        show_container_table(io, container; backend = Val(:auto))
    end
end

function Base.show(io::IO, ::MIME"text/html", container::InfrastructureSystemsContainer)
    num_members = get_num_members(container)
    member_str = get_member_string(container)
    println(io, "<h2>Members</h2>")
    println(io, "<p><b>Num $member_str</b>: $num_members</p>")
    if num_members > 0
        show_container_table(io, container; backend = Val(:html), standalone = false)
    end
end

make_label(type::Type{<:InfrastructureSystemsType}, name) = "$(nameof(type)): $name"
Base.summary(x::InfrastructureSystemsComponent) = make_label(typeof(x), get_name(x))
Base.summary(x::SupplementalAttribute) = make_label(typeof(x), get_uuid(x))
Base.summary(x::TimeSeriesData) = make_label(typeof(x), get_name(x))
Base.summary(x::TimeSeriesMetadata) = make_label(typeof(x), get_name(x))

function Base.show(io::IO, data::SystemData)
    show(io, data.components)
    println(io, "\n")
    show_time_series_data(io, data)
    show_supplemental_attributes_data(io, data)
end

function Base.show(io::IO, ::MIME"text/plain", data::SystemData)
    show(io, MIME"text/plain"(), data.components)
    println(io, "\n")
    show(io, MIME"text/plain"(), data.supplemental_attribute_manager)
    println(io, "\n")
    show_time_series_data(io, data; backend = Val(:auto))
    show_supplemental_attributes_data(io, data; backend = Val(:auto))
end

function Base.show(io::IO, ::MIME"text/html", data::SystemData)
    show(io, MIME"text/html"(), data.components)
    println(io, "\n")
    show(io, MIME"text/html"(), data.supplemental_attribute_manager)
    println(io, "\n")
    show_time_series_data(io, data; backend = Val(:html), standalone = false)
    show_supplemental_attributes_data(io, data; backend = Val(:html), standalone = false)
end

function show_time_series_data(io::IO, data::SystemData; kwargs...)
    table = get_time_series_summary_table(data)
    if !isempty(table)
        PrettyTables.pretty_table(
            io,
            table;
            title = "Time Series Summary",
            alignment = :l,
            kwargs...,
        )
    end
    return
end

function show_supplemental_attributes_data(io::IO, data::SystemData; kwargs...)
    table = get_supplemental_attribute_summary_table(data)
    if !isempty(table)
        PrettyTables.pretty_table(
            io,
            table;
            title = "Supplemental Attribute Summary",
            alignment = :l,
            kwargs...,
        )
    end
    return
end

function Base.show(io::IO, ::MIME"text/plain", system_units::SystemUnitsSettings)
    print(io, summary(system_units), ":")
    for name in fieldnames(typeof(system_units))
        val = getproperty(system_units, name)
        print(io, "\n      ", name, ": ", val)
    end
end

function Base.show(io::IO, ::MIME"text/plain", ist::InfrastructureSystemsComponent)
    print(io, summary(ist), ":")
    for name in fieldnames(typeof(ist))
        obj = getfield(ist, name)
        if obj isa InfrastructureSystemsInternal
            continue
        elseif obj isa InfrastructureSystemsType
            val = summary(getproperty(ist, name))
        elseif obj isa Vector{<:InfrastructureSystemsComponent}
            val = summary(getproperty(ist, name))
        else
            val = getproperty(ist, name)
        end
        print(io, "\n   ", name, ": ", val)
    end
    print(io, "\n   ", "has_time_series", ": ", string(has_time_series(ist)))
end

function Base.show(io::IO, ist::InfrastructureSystemsComponent)
    print(io, strip_module_name(typeof(ist)), "(")
    is_first = true
    for (name, field_type) in zip(fieldnames(typeof(ist)), fieldtypes(typeof(ist)))
        if field_type <: InfrastructureSystemsInternal
            continue
        else
            val = getproperty(ist, name)
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

function Base.show(io::IO, ::MIME"text/plain", internal::InfrastructureSystemsInternal)
    print(io, summary(internal), ":")
    for name in fieldnames(typeof(internal))
        name == :shared_system_references && continue
        val = getproperty(internal, name)
        print(io, "\n   ", name, ": ", val)
    end
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

function show_container_table(io::IO, container::InfrastructureSystemsContainer; kwargs...)
    header = ["Type", "Count", "Has Static Time Series", "Has Forecasts"]
    data = Array{Any, 2}(undef, length(container.data), length(header))

    type_names = [(strip_module_name(x), x) for x in keys(container.data)]
    sort!(type_names; by = x -> x[1])
    for (i, (type_name, type)) in enumerate(type_names)
        vals = container.data[type]
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

    title = strip_module_name(component_type)
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
            data[i, 2] = Base.getproperty(component, :available)
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
                val = Base.getproperty(component, column)
                if val isa InfrastructureSystemsType ||
                   val isa Vector{<:InfrastructureSystemsComponent}
                    val = summary(val)
                elseif hasproperty(parent, getter_name)
                    getter_func = Base.getproperty(parent, getter_name)
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

"""
Show a table with supplemental attributes attached to the component.
"""
function show_supplemental_attributes(component::InfrastructureSystemsComponent)
    show_supplemental_attributes(stdout, component)
end

function show_supplemental_attributes(io::IO, component::InfrastructureSystemsComponent)
    data_by_type = Dict{Any, Vector{OrderedDict{String, Any}}}()
    for attribute in get_supplemental_attributes(component)
        if !haskey(data_by_type, typeof(attribute))
            data_by_type[typeof(attribute)] = Vector{OrderedDict{String, Any}}()
        end
        data = OrderedDict{String, Any}()
        for field in fieldnames(typeof(attribute))
            if field != :internal
                data[string(field)] = Base.getproperty(attribute, field)
            end
        end
        push!(data_by_type[typeof(attribute)], data)
    end
    for (type, rows) in data_by_type
        PrettyTables.pretty_table(io, DataFrame(rows); title = string(nameof(type)))
    end
end

"""
Show a table with time series data attached to the component.
"""
function show_time_series(owner::TimeSeriesOwners)
    show_time_series(stdout, owner)
end

function show_time_series(io::IO, owner::TimeSeriesOwners)
    data_by_type = Dict{Any, Vector{OrderedDict{String, Any}}}()
    for key in list_time_series_keys(owner)
        ts_type = get_time_series_type(key)
        if !haskey(data_by_type, ts_type)
            data_by_type[ts_type] = Vector{OrderedDict{String, Any}}()
        end
        data = OrderedDict{String, Any}()
        for (fname, ftype) in zip(fieldnames(typeof(key)), fieldtypes(typeof(key)))
            if ftype <: Type{<:TimeSeriesData}
                data[string(fname)] = string(nameof(Base.getproperty(key, fname)))
            else
                data[string(fname)] = Base.getproperty(key, fname)
            end
        end
        push!(data_by_type[ts_type], data)
    end
    for rows in values(data_by_type)
        PrettyTables.pretty_table(io, DataFrame(rows))
    end
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
