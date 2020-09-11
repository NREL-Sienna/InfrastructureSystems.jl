#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct DeterministicMetadata <: TimeSeriesMetadata
        label::String
        resolution::Dates.Period
        initial_time::Dates.DateTime
        time_series_uuid::UUIDs.UUID
        horizon::Int
        internal::InfrastructureSystemsInternal
    end

A deterministic time series for a particular data field in a Component.

# Arguments
- `label::String`: user-defined label
- `resolution::Dates.Period`
- `initial_time::Dates.DateTime`: time series availability time
- `time_series_uuid::UUIDs.UUID`: reference to time series data; timestamp - scalingfactor
- `horizon::Int`: length of this time series
- `internal::InfrastructureSystemsInternal`
"""
mutable struct DeterministicMetadata <: TimeSeriesMetadata
    "user-defined label"
    label::String
    resolution::Dates.Period
    "time series availability time"
    initial_time::Dates.DateTime
    "reference to time series data; timestamp - scalingfactor"
    time_series_uuid::UUIDs.UUID
    "length of this time series"
    horizon::Int
    internal::InfrastructureSystemsInternal
end

function DeterministicMetadata(label, resolution, initial_time, time_series_uuid, horizon, )
    DeterministicMetadata(label, resolution, initial_time, time_series_uuid, horizon, InfrastructureSystemsInternal(), )
end

function DeterministicMetadata(; label, resolution, initial_time, time_series_uuid, horizon, internal=InfrastructureSystemsInternal(), )
    DeterministicMetadata(label, resolution, initial_time, time_series_uuid, horizon, internal, )
end

"""Get [`DeterministicMetadata`](@ref) `label`."""
get_label(value::DeterministicMetadata) = value.label
"""Get [`DeterministicMetadata`](@ref) `resolution`."""
get_resolution(value::DeterministicMetadata) = value.resolution
"""Get [`DeterministicMetadata`](@ref) `initial_time`."""
get_initial_time(value::DeterministicMetadata) = value.initial_time
"""Get [`DeterministicMetadata`](@ref) `time_series_uuid`."""
get_time_series_uuid(value::DeterministicMetadata) = value.time_series_uuid
"""Get [`DeterministicMetadata`](@ref) `horizon`."""
get_horizon(value::DeterministicMetadata) = value.horizon
"""Get [`DeterministicMetadata`](@ref) `internal`."""
get_internal(value::DeterministicMetadata) = value.internal

"""Set [`DeterministicMetadata`](@ref) `label`."""
set_label!(value::DeterministicMetadata, val) = value.label = val
"""Set [`DeterministicMetadata`](@ref) `resolution`."""
set_resolution!(value::DeterministicMetadata, val) = value.resolution = val
"""Set [`DeterministicMetadata`](@ref) `initial_time`."""
set_initial_time!(value::DeterministicMetadata, val) = value.initial_time = val
"""Set [`DeterministicMetadata`](@ref) `time_series_uuid`."""
set_time_series_uuid!(value::DeterministicMetadata, val) = value.time_series_uuid = val
"""Set [`DeterministicMetadata`](@ref) `horizon`."""
set_horizon!(value::DeterministicMetadata, val) = value.horizon = val
"""Set [`DeterministicMetadata`](@ref) `internal`."""
set_internal!(value::DeterministicMetadata, val) = value.internal = val

