const TimeSeriesOwners = Union{InfrastructureSystemsComponent, SupplementalAttribute}

@kwdef struct StaticTimeSeriesInfo <: InfrastructureSystemsType
    type::DataType
    name::String
    initial_timestamp::Dates.DateTime
    resolution::Dates.Period
    length::Int
    features::Dict{String, Any}
end

function make_time_series_info(metadata::StaticTimeSeriesMetadata)
    return StaticTimeSeriesInfo(;
        type = time_series_metadata_to_data(metadata),
        name = get_name(metadata),
        initial_timestamp = get_initial_timestamp(metadata),
        resolution = get_resolution(metadata),
        length = get_length(metadata),
        features = get_features(metadata),
    )
end

@kwdef struct ForecastInfo <: InfrastructureSystemsType
    type::DataType
    name::String
    initial_timestamp::Dates.DateTime
    resolution::Dates.Period
    horizon::Int
    interval::Dates.Period
    count::Int
    features::Dict{String, Any}
end

function make_time_series_info(metadata::ForecastMetadata)
    return ForecastInfo(;
        type = time_series_metadata_to_data(metadata),
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

# TODO: This is now only used in PSY. Consider moving.
@kwdef struct TimeSeriesKey <: InfrastructureSystemsType
    time_series_type::Type{<:TimeSeriesData}
    name::String
end

function TimeSeriesKey(data::TimeSeriesData)
    return TimeSeriesKey(typeof(data), get_name(data))
end

function deserialize_struct(::Type{TimeSeriesKey}, data::Dict)
    vals = Dict{Symbol, Any}()
    for field_name in fieldnames(TimeSeriesKey)
        val = data[string(field_name)]
        if field_name == :time_series_type
            val = getfield(InfrastructureSystems, Symbol(strip_module_name(val)))
        end
        vals[field_name] = val
    end
    return TimeSeriesKey(; vals...)
end
