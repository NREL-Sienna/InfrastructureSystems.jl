abstract type TimeSeriesParameter <: RightHandSideParameter end

"""
Function to create a unique index of time series names for each device model. For example,
if two parameters each reference the same time series name, this function will return a
different value for each parameter entry
"""
function create_time_series_multiplier_index(
    model, #TODO: create the correct abstraction here
    ::Type{T},
) where {T <: TimeSeriesParameter}
    # ts_names = get_time_series_names(model) #TODO:
    if length(ts_names) > 1
        ts_name = ts_names[T]
        ts_id = findfirst(x -> x == T, [k for (k, v) in ts_names if v == ts_name])
    else
        ts_id = 1
    end
    return ts_id
end
