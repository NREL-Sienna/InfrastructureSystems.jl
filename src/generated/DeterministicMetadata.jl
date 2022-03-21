#=
This file is auto-generated. Do not edit.
=#

#! format: off

"""
    mutable struct DeterministicMetadata <: ForecastMetadata
        name::String
        resolution::Dates.Period
        initial_timestamp::Dates.DateTime
        interval::Dates.Period
        count::Int
        time_series_uuid::UUIDs.UUID
        horizon::Int
        time_series_type::Type{<:AbstractDeterministic}
        scaling_factor_multiplier::Union{Nothing, Function}
        internal::InfrastructureSystemsInternal
    end

A deterministic forecast for a particular data field in a Component.

# Arguments
- `name::String`: user-defined name
- `resolution::Dates.Period`
- `initial_timestamp::Dates.DateTime`: time series availability time
- `interval::Dates.Period`: time step between forecast windows
- `count::Int`: number of forecast windows
- `time_series_uuid::UUIDs.UUID`: reference to time series data
- `horizon::Int`: length of this time series
- `time_series_type::Type{<:AbstractDeterministic}`: Type of the time series data associated with this metadata.
- `scaling_factor_multiplier::Union{Nothing, Function}`: Applicable when the time series data are scaling factors. Called on the associated component to convert the values.
- `internal::InfrastructureSystemsInternal`
"""
mutable struct DeterministicMetadata <: ForecastMetadata
    "user-defined name"
    name::String
    resolution::Dates.Period
    "time series availability time"
    initial_timestamp::Dates.DateTime
    "time step between forecast windows"
    interval::Dates.Period
    "number of forecast windows"
    count::Int
    "reference to time series data"
    time_series_uuid::UUIDs.UUID
    "length of this time series"
    horizon::Int
    "Type of the time series data associated with this metadata."
    time_series_type::Type{<:AbstractDeterministic}
    "Applicable when the time series data are scaling factors. Called on the associated component to convert the values."
    scaling_factor_multiplier::Union{Nothing, Function}
    internal::InfrastructureSystemsInternal
end

function DeterministicMetadata(name, resolution, initial_timestamp, interval, count, time_series_uuid, horizon, time_series_type, scaling_factor_multiplier=nothing, )
    DeterministicMetadata(name, resolution, initial_timestamp, interval, count, time_series_uuid, horizon, time_series_type, scaling_factor_multiplier, InfrastructureSystemsInternal(), )
end

function DeterministicMetadata(; name, resolution, initial_timestamp, interval, count, time_series_uuid, horizon, time_series_type, scaling_factor_multiplier=nothing, internal=InfrastructureSystemsInternal(), )
    DeterministicMetadata(name, resolution, initial_timestamp, interval, count, time_series_uuid, horizon, time_series_type, scaling_factor_multiplier, internal, )
end

"""Get [`DeterministicMetadata`](@ref) `name`."""
get_name(value::DeterministicMetadata) = value.name
"""Get [`DeterministicMetadata`](@ref) `resolution`."""
get_resolution(value::DeterministicMetadata) = value.resolution
"""Get [`DeterministicMetadata`](@ref) `initial_timestamp`."""
get_initial_timestamp(value::DeterministicMetadata) = value.initial_timestamp
"""Get [`DeterministicMetadata`](@ref) `interval`."""
get_interval(value::DeterministicMetadata) = value.interval
"""Get [`DeterministicMetadata`](@ref) `count`."""
get_count(value::DeterministicMetadata) = value.count
"""Get [`DeterministicMetadata`](@ref) `time_series_uuid`."""
get_time_series_uuid(value::DeterministicMetadata) = value.time_series_uuid
"""Get [`DeterministicMetadata`](@ref) `horizon`."""
get_horizon(value::DeterministicMetadata) = value.horizon
"""Get [`DeterministicMetadata`](@ref) `time_series_type`."""
get_time_series_type(value::DeterministicMetadata) = value.time_series_type
"""Get [`DeterministicMetadata`](@ref) `scaling_factor_multiplier`."""
get_scaling_factor_multiplier(value::DeterministicMetadata) = value.scaling_factor_multiplier
"""Get [`DeterministicMetadata`](@ref) `internal`."""
get_internal(value::DeterministicMetadata) = value.internal

"""Set [`DeterministicMetadata`](@ref) `name`."""
set_name!(value::DeterministicMetadata, val) = value.name = val
"""Set [`DeterministicMetadata`](@ref) `resolution`."""
set_resolution!(value::DeterministicMetadata, val) = value.resolution = val
"""Set [`DeterministicMetadata`](@ref) `initial_timestamp`."""
set_initial_timestamp!(value::DeterministicMetadata, val) = value.initial_timestamp = val
"""Set [`DeterministicMetadata`](@ref) `interval`."""
set_interval!(value::DeterministicMetadata, val) = value.interval = val
"""Set [`DeterministicMetadata`](@ref) `count`."""
set_count!(value::DeterministicMetadata, val) = value.count = val
"""Set [`DeterministicMetadata`](@ref) `time_series_uuid`."""
set_time_series_uuid!(value::DeterministicMetadata, val) = value.time_series_uuid = val
"""Set [`DeterministicMetadata`](@ref) `horizon`."""
set_horizon!(value::DeterministicMetadata, val) = value.horizon = val
"""Set [`DeterministicMetadata`](@ref) `time_series_type`."""
set_time_series_type!(value::DeterministicMetadata, val) = value.time_series_type = val
"""Set [`DeterministicMetadata`](@ref) `scaling_factor_multiplier`."""
set_scaling_factor_multiplier!(value::DeterministicMetadata, val) = value.scaling_factor_multiplier = val
"""Set [`DeterministicMetadata`](@ref) `internal`."""
set_internal!(value::DeterministicMetadata, val) = value.internal = val
