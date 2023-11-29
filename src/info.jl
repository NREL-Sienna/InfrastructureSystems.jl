"""
Return true if the info has time series data.
"""
function has_time_series(info::InfrastructureSystemsInfo)
    container = get_time_series_container(info)
    return !isnothing(container) && !isempty(container)
end

function set_time_series_storage!(
    component::InfrastructureSystemsInfo,
    storage::Union{Nothing, TimeSeriesStorage},
)
    container = get_time_series_container(component)
    if !isnothing(container)
        set_time_series_storage!(container, storage)
    end
end
