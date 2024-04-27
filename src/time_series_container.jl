"""
Time series container for a component.
"""
mutable struct TimeSeriesContainer
    manager::Union{Nothing, TimeSeriesManager}
end

function TimeSeriesContainer(; manager = nothing)
    return TimeSeriesContainer(manager)
end

get_time_series_manager(x::TimeSeriesContainer) = x.manager

function set_time_series_manager!(
    container::TimeSeriesContainer,
    time_series_manager::Union{Nothing, TimeSeriesManager},
)
    if !isnothing(container.manager) && !isnothing(time_series_manager)
        throw(
            ArgumentError(
                "The time_series_manager reference is already set. Is this component being " *
                "added to multiple systems?",
            ),
        )
    end

    container.manager = time_series_manager
    return
end

serialize(::TimeSeriesContainer) = Dict()
deserialize(::Type{TimeSeriesContainer}, ::Dict) = TimeSeriesContainer()
