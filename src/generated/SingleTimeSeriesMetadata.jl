#=
This file is auto-generated. Do not edit.
=#

#! format: off

"""
    mutable struct SingleTimeSeriesMetadata <: StaticTimeSeriesMetadata
        name::String
        resolution::Dates.Period
        initial_timestamp::Dates.DateTime
        time_series_uuid::UUIDs.UUID
        length::Int
        scaling_factor_multiplier::Union{Nothing, Function}
        internal::InfrastructureSystemsInternal
    end

A TimeSeries Data object in contigous form.

# Arguments
- `name::String`: user-defined name
- `resolution::Dates.Period`
- `initial_timestamp::Dates.DateTime`: time series availability time
- `time_series_uuid::UUIDs.UUID`: reference to time series data
- `length::Int`: length of this time series
- `scaling_factor_multiplier::Union{Nothing, Function}`: Applicable when the time series data are scaling factors. Called on the associated component to convert the values.
- `internal::InfrastructureSystemsInternal`
"""
mutable struct SingleTimeSeriesMetadata <: StaticTimeSeriesMetadata
    "user-defined name"
    name::String
    resolution::Dates.Period
    "time series availability time"
    initial_timestamp::Dates.DateTime
    "reference to time series data"
    time_series_uuid::UUIDs.UUID
    "length of this time series"
    length::Int
    "Applicable when the time series data are scaling factors. Called on the associated component to convert the values."
    scaling_factor_multiplier::Union{Nothing, Function}
    internal::InfrastructureSystemsInternal
end

function SingleTimeSeriesMetadata(name, resolution, initial_timestamp, time_series_uuid, length, scaling_factor_multiplier=nothing, )
    SingleTimeSeriesMetadata(name, resolution, initial_timestamp, time_series_uuid, length, scaling_factor_multiplier, InfrastructureSystemsInternal(), )
end

function SingleTimeSeriesMetadata(; name, resolution, initial_timestamp, time_series_uuid, length, scaling_factor_multiplier=nothing, internal=InfrastructureSystemsInternal(), )
    SingleTimeSeriesMetadata(name, resolution, initial_timestamp, time_series_uuid, length, scaling_factor_multiplier, internal, )
end

"""Get [`SingleTimeSeriesMetadata`](@ref) `name`."""
get_name(value::SingleTimeSeriesMetadata) = value.name
"""Get [`SingleTimeSeriesMetadata`](@ref) `resolution`."""
get_resolution(value::SingleTimeSeriesMetadata) = value.resolution
"""Get [`SingleTimeSeriesMetadata`](@ref) `initial_timestamp`."""
get_initial_timestamp(value::SingleTimeSeriesMetadata) = value.initial_timestamp
"""Get [`SingleTimeSeriesMetadata`](@ref) `time_series_uuid`."""
get_time_series_uuid(value::SingleTimeSeriesMetadata) = value.time_series_uuid
"""Get [`SingleTimeSeriesMetadata`](@ref) `length`."""
get_length(value::SingleTimeSeriesMetadata) = value.length
"""Get [`SingleTimeSeriesMetadata`](@ref) `scaling_factor_multiplier`."""
get_scaling_factor_multiplier(value::SingleTimeSeriesMetadata) = value.scaling_factor_multiplier
"""Get [`SingleTimeSeriesMetadata`](@ref) `internal`."""
get_internal(value::SingleTimeSeriesMetadata) = value.internal

"""Set [`SingleTimeSeriesMetadata`](@ref) `name`."""
set_name!(value::SingleTimeSeriesMetadata, val) = value.name = val
"""Set [`SingleTimeSeriesMetadata`](@ref) `resolution`."""
set_resolution!(value::SingleTimeSeriesMetadata, val) = value.resolution = val
"""Set [`SingleTimeSeriesMetadata`](@ref) `initial_timestamp`."""
set_initial_timestamp!(value::SingleTimeSeriesMetadata, val) = value.initial_timestamp = val
"""Set [`SingleTimeSeriesMetadata`](@ref) `time_series_uuid`."""
set_time_series_uuid!(value::SingleTimeSeriesMetadata, val) = value.time_series_uuid = val
"""Set [`SingleTimeSeriesMetadata`](@ref) `length`."""
set_length!(value::SingleTimeSeriesMetadata, val) = value.length = val
"""Set [`SingleTimeSeriesMetadata`](@ref) `scaling_factor_multiplier`."""
set_scaling_factor_multiplier!(value::SingleTimeSeriesMetadata, val) = value.scaling_factor_multiplier = val
"""Set [`SingleTimeSeriesMetadata`](@ref) `internal`."""
set_internal!(value::SingleTimeSeriesMetadata, val) = value.internal = val

get_horizon(val::SingleTimeSeriesMetadata) = get_length(val)
