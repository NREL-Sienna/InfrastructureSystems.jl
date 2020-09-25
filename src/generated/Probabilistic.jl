#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct Probabilistic <: Forecast
        name::String
        initial_time_stamp::Dates.DateTime
        horizon::Int
        resolution::Dates.Period
        percentiles::Vector{Float64}
        data::SortedDict{Dates.DateTime, Array}
        scaling_factor_multiplier::Union{Nothing, Function}
        internal::InfrastructureSystemsInternal
    end

A Probabilistic forecast for a particular data field in a Component.

# Arguments
- `name::String`: user-defined name
- `initial_time_stamp::Dates.DateTime`: first timestamp in forecast
- `horizon::Int`: length of this time series
- `resolution::Dates.Period`: forecast resolution
- `percentiles::Vector{Float64}`: Percentiles for the probabilistic forecast
- `data::SortedDict{Dates.DateTime, Array}`: timestamp - scalingfactor
- `scaling_factor_multiplier::Union{Nothing, Function}`: Applicable when the time series data are scaling factors. Called on the associated component to convert the values.
- `internal::InfrastructureSystemsInternal`
"""
mutable struct Probabilistic <: Forecast
    "user-defined name"
    name::String
    "first timestamp in forecast"
    initial_time_stamp::Dates.DateTime
    "length of this time series"
    horizon::Int
    "forecast resolution"
    resolution::Dates.Period
    "Percentiles for the probabilistic forecast"
    percentiles::Vector{Float64}
    "timestamp - scalingfactor"
    data::SortedDict{Dates.DateTime, Array}
    "Applicable when the time series data are scaling factors. Called on the associated component to convert the values."
    scaling_factor_multiplier::Union{Nothing, Function}
    internal::InfrastructureSystemsInternal
end

function Probabilistic(name, initial_time_stamp, horizon, resolution, percentiles, data, scaling_factor_multiplier=nothing, )
    Probabilistic(name, initial_time_stamp, horizon, resolution, percentiles, data, scaling_factor_multiplier, InfrastructureSystemsInternal(), )
end

function Probabilistic(; name, initial_time_stamp, horizon, resolution, percentiles, data, scaling_factor_multiplier=nothing, internal=InfrastructureSystemsInternal(), )
    Probabilistic(name, initial_time_stamp, horizon, resolution, percentiles, data, scaling_factor_multiplier, internal, )
end

"""Get [`Probabilistic`](@ref) `name`."""
get_name(value::Probabilistic) = value.name
"""Get [`Probabilistic`](@ref) `initial_time_stamp`."""
get_initial_time_stamp(value::Probabilistic) = value.initial_time_stamp
"""Get [`Probabilistic`](@ref) `horizon`."""
get_horizon(value::Probabilistic) = value.horizon
"""Get [`Probabilistic`](@ref) `resolution`."""
get_resolution(value::Probabilistic) = value.resolution
"""Get [`Probabilistic`](@ref) `percentiles`."""
get_percentiles(value::Probabilistic) = value.percentiles
"""Get [`Probabilistic`](@ref) `data`."""
get_data(value::Probabilistic) = value.data
"""Get [`Probabilistic`](@ref) `scaling_factor_multiplier`."""
get_scaling_factor_multiplier(value::Probabilistic) = value.scaling_factor_multiplier
"""Get [`Probabilistic`](@ref) `internal`."""
get_internal(value::Probabilistic) = value.internal

"""Set [`Probabilistic`](@ref) `name`."""
set_name!(value::Probabilistic, val) = value.name = val
"""Set [`Probabilistic`](@ref) `initial_time_stamp`."""
set_initial_time_stamp!(value::Probabilistic, val) = value.initial_time_stamp = val
"""Set [`Probabilistic`](@ref) `horizon`."""
set_horizon!(value::Probabilistic, val) = value.horizon = val
"""Set [`Probabilistic`](@ref) `resolution`."""
set_resolution!(value::Probabilistic, val) = value.resolution = val
"""Set [`Probabilistic`](@ref) `percentiles`."""
set_percentiles!(value::Probabilistic, val) = value.percentiles = val
"""Set [`Probabilistic`](@ref) `data`."""
set_data!(value::Probabilistic, val) = value.data = val
"""Set [`Probabilistic`](@ref) `scaling_factor_multiplier`."""
set_scaling_factor_multiplier!(value::Probabilistic, val) = value.scaling_factor_multiplier = val
"""Set [`Probabilistic`](@ref) `internal`."""
set_internal!(value::Probabilistic, val) = value.internal = val

