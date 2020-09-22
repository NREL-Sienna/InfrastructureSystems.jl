#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct DeterministicMetadata <: TimeSeriesMetadata
        label::String
        resolution::Dates.Period
        initial_time_stamp::Dates.DateTime
        interval::Dates.Period
        time_series_uuid::UUIDs.UUID
        horizon::Int
        scaling_factor_multiplier::Union{Nothing, Function}
        internal::InfrastructureSystemsInternal
    end

A deterministic time series for a particular data field in a Component.

# Arguments
- `label::String`: user-defined label
- `resolution::Dates.Period`
- `initial_time_stamp::Dates.DateTime`: time series availability time
- `interval::Dates.Period`: time series availability time
- `time_series_uuid::UUIDs.UUID`: reference to time series data
- `horizon::Int`: length of this time series
- `scaling_factor_multiplier::Union{Nothing, Function}`: Applicable when the time series data are scaling factors. Called on the associated component to convert the values.
- `internal::InfrastructureSystemsInternal`
"""
mutable struct DeterministicMetadata <: TimeSeriesMetadata
    "user-defined label"
    label::String
    resolution::Dates.Period
    "time series availability time"
    initial_time_stamp::Dates.DateTime
    "time series availability time"
    interval::Dates.Period
    "reference to time series data"
    time_series_uuid::UUIDs.UUID
    "length of this time series"
    horizon::Int
    "Applicable when the time series data are scaling factors. Called on the associated component to convert the values."
    scaling_factor_multiplier::Union{Nothing, Function}
    internal::InfrastructureSystemsInternal
end

function DeterministicMetadata(label, resolution, initial_time_stamp, interval, time_series_uuid, horizon, scaling_factor_multiplier=nothing, )
    DeterministicMetadata(label, resolution, initial_time_stamp, interval, time_series_uuid, horizon, scaling_factor_multiplier, InfrastructureSystemsInternal(), )
end

function DeterministicMetadata(; label, resolution, initial_time_stamp, interval, time_series_uuid, horizon, scaling_factor_multiplier=nothing, internal=InfrastructureSystemsInternal(), )
    DeterministicMetadata(label, resolution, initial_time_stamp, interval, time_series_uuid, horizon, scaling_factor_multiplier, internal, )
end

"""Get [`DeterministicMetadata`](@ref) `label`."""
get_label(value::DeterministicMetadata) = value.label
"""Get [`DeterministicMetadata`](@ref) `resolution`."""
get_resolution(value::DeterministicMetadata) = value.resolution
"""Get [`DeterministicMetadata`](@ref) `initial_time_stamp`."""
get_initial_time_stamp(value::DeterministicMetadata) = value.initial_time_stamp
"""Get [`DeterministicMetadata`](@ref) `interval`."""
get_interval(value::DeterministicMetadata) = value.interval
"""Get [`DeterministicMetadata`](@ref) `time_series_uuid`."""
get_time_series_uuid(value::DeterministicMetadata) = value.time_series_uuid
"""Get [`DeterministicMetadata`](@ref) `horizon`."""
get_horizon(value::DeterministicMetadata) = value.horizon
"""Get [`DeterministicMetadata`](@ref) `scaling_factor_multiplier`."""
get_scaling_factor_multiplier(value::DeterministicMetadata) = value.scaling_factor_multiplier
"""Get [`DeterministicMetadata`](@ref) `internal`."""
get_internal(value::DeterministicMetadata) = value.internal

"""Set [`DeterministicMetadata`](@ref) `label`."""
set_label!(value::DeterministicMetadata, val) = value.label = val
"""Set [`DeterministicMetadata`](@ref) `resolution`."""
set_resolution!(value::DeterministicMetadata, val) = value.resolution = val
"""Set [`DeterministicMetadata`](@ref) `initial_time_stamp`."""
set_initial_time_stamp!(value::DeterministicMetadata, val) = value.initial_time_stamp = val
"""Set [`DeterministicMetadata`](@ref) `interval`."""
set_interval!(value::DeterministicMetadata, val) = value.interval = val
"""Set [`DeterministicMetadata`](@ref) `time_series_uuid`."""
set_time_series_uuid!(value::DeterministicMetadata, val) = value.time_series_uuid = val
"""Set [`DeterministicMetadata`](@ref) `horizon`."""
set_horizon!(value::DeterministicMetadata, val) = value.horizon = val
"""Set [`DeterministicMetadata`](@ref) `scaling_factor_multiplier`."""
set_scaling_factor_multiplier!(value::DeterministicMetadata, val) = value.scaling_factor_multiplier = val
"""Set [`DeterministicMetadata`](@ref) `internal`."""
set_internal!(value::DeterministicMetadata, val) = value.internal = val

