#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct SingleTimeSeriesMetadata <: StaticTimeSeriesMetadata
        label::String
        resolution::Dates.Period
        initial_time::Dates.DateTime
        time_series_uuid::UUIDs.UUID
        length::Int
        scaling_factor_multiplier::Union{Nothing, Function}
        internal::InfrastructureSystemsInternal
    end

A TimeSeries Data object in contigous form.

# Arguments
- `label::String`: user-defined label
- `resolution::Dates.Period`
- `initial_time::Dates.DateTime`: time series availability time
- `time_series_uuid::UUIDs.UUID`: reference to time series data
- `length::Int`: length of this time series
- `scaling_factor_multiplier::Union{Nothing, Function}`: Applicable when the time series data are scaling factors. Called on the associated component to convert the values.
- `internal::InfrastructureSystemsInternal`
"""
mutable struct SingleTimeSeriesMetadata <: StaticTimeSeriesMetadata
    "user-defined label"
    label::String
    resolution::Dates.Period
    "time series availability time"
    initial_time::Dates.DateTime
    "reference to time series data"
    time_series_uuid::UUIDs.UUID
    "length of this time series"
    length::Int
    "Applicable when the time series data are scaling factors. Called on the associated component to convert the values."
    scaling_factor_multiplier::Union{Nothing, Function}
    internal::InfrastructureSystemsInternal
end

function SingleTimeSeriesMetadata(label, resolution, initial_time, time_series_uuid, length, scaling_factor_multiplier=nothing, )
    SingleTimeSeriesMetadata(label, resolution, initial_time, time_series_uuid, length, scaling_factor_multiplier, InfrastructureSystemsInternal(), )
end

function SingleTimeSeriesMetadata(; label, resolution, initial_time, time_series_uuid, length, scaling_factor_multiplier=nothing, internal=InfrastructureSystemsInternal(), )
    SingleTimeSeriesMetadata(label, resolution, initial_time, time_series_uuid, length, scaling_factor_multiplier, internal, )
end

"""Get [`SingleTimeSeriesMetadata`](@ref) `label`."""
get_label(value::SingleTimeSeriesMetadata) = value.label
"""Get [`SingleTimeSeriesMetadata`](@ref) `resolution`."""
get_resolution(value::SingleTimeSeriesMetadata) = value.resolution
"""Get [`SingleTimeSeriesMetadata`](@ref) `initial_time`."""
get_initial_time(value::SingleTimeSeriesMetadata) = value.initial_time
"""Get [`SingleTimeSeriesMetadata`](@ref) `time_series_uuid`."""
get_time_series_uuid(value::SingleTimeSeriesMetadata) = value.time_series_uuid
"""Get [`SingleTimeSeriesMetadata`](@ref) `length`."""
get_length(value::SingleTimeSeriesMetadata) = value.length
"""Get [`SingleTimeSeriesMetadata`](@ref) `scaling_factor_multiplier`."""
get_scaling_factor_multiplier(value::SingleTimeSeriesMetadata) = value.scaling_factor_multiplier
"""Get [`SingleTimeSeriesMetadata`](@ref) `internal`."""
get_internal(value::SingleTimeSeriesMetadata) = value.internal

"""Set [`SingleTimeSeriesMetadata`](@ref) `label`."""
set_label!(value::SingleTimeSeriesMetadata, val) = value.label = val
"""Set [`SingleTimeSeriesMetadata`](@ref) `resolution`."""
set_resolution!(value::SingleTimeSeriesMetadata, val) = value.resolution = val
"""Set [`SingleTimeSeriesMetadata`](@ref) `initial_time`."""
set_initial_time!(value::SingleTimeSeriesMetadata, val) = value.initial_time = val
"""Set [`SingleTimeSeriesMetadata`](@ref) `time_series_uuid`."""
set_time_series_uuid!(value::SingleTimeSeriesMetadata, val) = value.time_series_uuid = val
"""Set [`SingleTimeSeriesMetadata`](@ref) `length`."""
set_length!(value::SingleTimeSeriesMetadata, val) = value.length = val
"""Set [`SingleTimeSeriesMetadata`](@ref) `scaling_factor_multiplier`."""
set_scaling_factor_multiplier!(value::SingleTimeSeriesMetadata, val) = value.scaling_factor_multiplier = val
"""Set [`SingleTimeSeriesMetadata`](@ref) `internal`."""
set_internal!(value::SingleTimeSeriesMetadata, val) = value.internal = val

get_horizon(val::SingleTimeSeriesMetadata) = get_length(val)
