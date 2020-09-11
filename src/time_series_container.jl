struct TimeSeriesKey
    time_series_type::Type{<:TimeSeriesMetadata}
    initial_time::Dates.DateTime
    label::String
end

const TimeSeriesByType = Dict{TimeSeriesKey, TimeSeriesMetadata}

"""
Time series container for a component.
"""
mutable struct TimeSeriesContainer
    data::TimeSeriesByType
    time_series_storage::Union{Nothing, TimeSeriesStorage}
end

function TimeSeriesContainer()
    return TimeSeriesContainer(TimeSeriesByType(), nothing)
end

Base.length(container::TimeSeriesContainer) = length(container.data)
Base.isempty(container::TimeSeriesContainer) = isempty(container.data)

function set_time_series_storage!(
    container::TimeSeriesContainer,
    storage::Union{Nothing, TimeSeriesStorage},
)
    if !isnothing(container.time_series_storage) && !isnothing(storage)
        throw(ArgumentError(
            "The time_series_storage reference is already set. Is this component being " *
            "added to multiple systems?",
        ))
    end

    container.time_series_storage = storage
end

function add_time_series!(
    container::TimeSeriesContainer,
    time_series::T;
    skip_if_present = false,
) where {T <: TimeSeriesMetadata}
    key = TimeSeriesKey(T, get_initial_time(time_series), get_label(time_series))
    if haskey(container.data, key)
        if skip_if_present
            @warn "time_series $key is already present, skipping overwrite"
        else
            throw(ArgumentError("time_series $key is already stored"))
        end
    else
        container.data[key] = time_series
    end
end

function remove_time_series!(
    ::Type{T},
    container::TimeSeriesContainer,
    initial_time::Dates.DateTime,
    label::AbstractString,
) where {T <: TimeSeriesMetadata}
    key = TimeSeriesKey(T, initial_time, label)
    if !haskey(container.data, key)
        throw(ArgumentError("time_series $key is not stored"))
    end

    pop!(container.data, key)
end

function clear_time_series!(container::TimeSeriesContainer)
    empty!(container.data)
end

function get_time_series(
    ::Type{T},
    container::TimeSeriesContainer,
    initial_time::Dates.DateTime,
    label::AbstractString,
) where {T <: TimeSeriesMetadata}
    key = TimeSeriesKey(T, initial_time, label)
    if !haskey(container.data, key)
        throw(ArgumentError("time_series $key is not stored"))
    end

    return container.data[key]
end

function get_time_series_initial_times(container::TimeSeriesContainer)
    initial_times = Set{Dates.DateTime}()
    for key in keys(container.data)
        push!(initial_times, key.initial_time)
    end

    return sort!(Vector{Dates.DateTime}(collect(initial_times)))
end

function get_time_series_initial_times(
    ::Type{T},
    container::TimeSeriesContainer,
) where {T <: TimeSeriesMetadata}
    initial_times = Set{Dates.DateTime}()
    for key in keys(container.data)
        if key.time_series_type <: T
            push!(initial_times, key.initial_time)
        end
    end

    return sort!(Vector{Dates.DateTime}(collect(initial_times)))
end

function get_time_series_initial_times(
    ::Type{T},
    container::TimeSeriesContainer,
    label::AbstractString,
) where {T <: TimeSeriesMetadata}
    initial_times = Set{Dates.DateTime}()
    for key in keys(container.data)
        if key.time_series_type <: T && key.label == label
            push!(initial_times, key.initial_time)
        end
    end

    return sort!(Vector{Dates.DateTime}(collect(initial_times)))
end

function get_time_series_initial_times!(
    initial_times::Set{Dates.DateTime},
    container::TimeSeriesContainer,
)
    for key in keys(container.data)
        push!(initial_times, key.initial_time)
    end
end

function get_time_series_labels(
    ::Type{T},
    container::TimeSeriesContainer,
    initial_time::Dates.DateTime,
) where {T <: TimeSeriesMetadata}
    labels = Set{String}()
    for key in keys(container.data)
        if key.time_series_type <: T && key.initial_time == initial_time
            push!(labels, key.label)
        end
    end

    return Vector{String}(collect(labels))
end

function serialize(container::TimeSeriesContainer)
    # Store a flat array of time series. Deserialization can unwind it.
    return serialize_struct.(values(container.data))
end

function deserialize(::Type{TimeSeriesContainer}, data::Vector)
    container = TimeSeriesContainer()
    for ts_dict in data
        type = get_type_from_serialization_metadata(get_serialization_metadata(ts_dict))
        time_series = deserialize(type, ts_dict)
        add_time_series!(container, time_series)
    end

    return container
end
