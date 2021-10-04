struct TimeSeriesKey <: InfrastructureSystemsType
    time_series_type::Type{<:TimeSeriesMetadata}
    name::String
end

function TimeSeriesKey(; time_series_type::Type{<:TimeSeriesMetadata}, name::String)
    return TimeSeriesKey(time_series_type, name)
end

function TimeSeriesKey(data::TimeSeriesData)
    metadata_type = time_series_data_to_metadata(typeof(data))
    return TimeSeriesKey(metadata_type, get_name(data))
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
        throw(
            ArgumentError(
                "The time_series_storage reference is already set. Is this component being " *
                "added to multiple systems?",
            ),
        )
    end

    container.time_series_storage = storage
    return
end

function add_time_series!(
    container::TimeSeriesContainer,
    ts_metadata::T;
    skip_if_present = false,
) where {T <: TimeSeriesMetadata}
    key = TimeSeriesKey(T, get_name(ts_metadata))
    if haskey(container.data, key)
        if skip_if_present
            @warn "time_series $key is already present, skipping overwrite"
        else
            throw(ArgumentError("time_series $key is already stored"))
        end
    else
        container.data[key] = ts_metadata
    end
end

function remove_time_series!(
    container::TimeSeriesContainer,
    ::Type{T},
    name::AbstractString,
) where {T <: TimeSeriesMetadata}
    key = TimeSeriesKey(T, name)
    if !haskey(container.data, key)
        throw(ArgumentError("time_series $key is not stored"))
    end

    pop!(container.data, key)
    return
end

function clear_time_series!(container::TimeSeriesContainer)
    empty!(container.data)
    return
end

function get_time_series(
    ::Type{T},
    container::TimeSeriesContainer,
    name::AbstractString,
) where {T <: TimeSeriesMetadata}
    key = TimeSeriesKey(T, name)
    if !haskey(container.data, key)
        throw(ArgumentError("time_series $key is not stored"))
    end

    return container.data[key]
end

function get_time_series_names(
    ::Type{T},
    container::TimeSeriesContainer,
) where {T <: TimeSeriesMetadata}
    names = Set{String}()
    for key in keys(container.data)
        if key.time_series_type <: T
            push!(names, key.name)
        end
    end

    return Vector{String}(collect(names))
end

function has_time_series_internal(
    container::TimeSeriesContainer,
    ::Type{T},
    name::AbstractString,
) where {T <: TimeSeriesMetadata}
    return haskey(container.data, TimeSeriesKey(T, name))
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
