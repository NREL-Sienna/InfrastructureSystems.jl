const TimeSeriesOwners = Union{InfrastructureSystemsComponent, SupplementalAttribute}

# Required methods:
# - get_name
# - get_time_series_type
# The default methods rely on the field names name and time_series_type.
abstract type TimeSeriesKey <: InfrastructureSystemsType end

get_name(key::TimeSeriesKey) = key.name
get_time_series_type(key::TimeSeriesKey) = key.time_series_type

function deserialize_struct(T::Type{<:TimeSeriesKey}, data::Dict)
    vals = Dict{Symbol, Any}()
    for (field_name, field_type) in zip(fieldnames(T), fieldtypes(T))
        val = data[string(field_name)]
        if field_type <: Type{<:TimeSeriesData}
            metadata = get_serialization_metadata(val)
            val = get_type_from_serialization_metadata(metadata)
        else
            val = deserialize(field_type, val)
        end
        vals[field_name] = val
    end
    return T(; vals...)
end

@kwdef struct StaticTimeSeriesKey <: TimeSeriesKey
    time_series_type::Type{<:StaticTimeSeries}
    name::String
    initial_timestamp::Dates.DateTime
    resolution::Dates.Period
    length::Int
    features::Dict{String, Any}
end

function make_time_series_key(metadata::StaticTimeSeriesMetadata)
    return StaticTimeSeriesKey(;
        time_series_type = time_series_metadata_to_data(metadata),
        name = get_name(metadata),
        initial_timestamp = get_initial_timestamp(metadata),
        resolution = get_resolution(metadata),
        length = get_length(metadata),
        features = get_features(metadata),
    )
end

@kwdef struct ForecastKey <: TimeSeriesKey
    time_series_type::Type{<:Forecast}
    name::String
    initial_timestamp::Dates.DateTime
    resolution::Dates.Period
    horizon::Int
    interval::Dates.Period
    count::Int
    features::Dict{String, Any}
end

function make_time_series_key(metadata::ForecastMetadata)
    return ForecastKey(;
        time_series_type = time_series_metadata_to_data(metadata),
        name = get_name(metadata),
        initial_timestamp = get_initial_timestamp(metadata),
        resolution = get_resolution(metadata),
        horizon = get_horizon(metadata),
        interval = get_interval(metadata),
        count = get_count(metadata),
        features = get_features(metadata),
    )
end

"""
Provides counts of time series including attachments to components and supplemental
attributes.
"""
@kwdef struct TimeSeriesCounts
    components_with_time_series::Int
    supplemental_attributes_with_time_series::Int
    static_time_series_count::Int
    forecast_count::Int
end
