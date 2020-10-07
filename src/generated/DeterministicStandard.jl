#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct DeterministicStandard <: Forecast
        name::String
        resolution::Dates.Period
        data::SortedDict{Dates.DateTime, Vector}
        scaling_factor_multiplier::Union{Nothing, Function}
        internal::InfrastructureSystemsInternal
    end

A deterministic forecast for a particular data field in a Component.

# Arguments
- `name::String`: user-defined name
- `resolution::Dates.Period`: forecast resolution
- `data::SortedDict{Dates.DateTime, Vector}`: timestamp - scalingfactor
- `scaling_factor_multiplier::Union{Nothing, Function}`: Applicable when the time series data are scaling factors. Called on the associated component to convert the values.
- `internal::InfrastructureSystemsInternal`
"""
mutable struct DeterministicStandard <: Forecast
    "user-defined name"
    name::String
    "forecast resolution"
    resolution::Dates.Period
    "timestamp - scalingfactor"
    data::SortedDict{Dates.DateTime, Vector}
    "Applicable when the time series data are scaling factors. Called on the associated component to convert the values."
    scaling_factor_multiplier::Union{Nothing, Function}
    internal::InfrastructureSystemsInternal
end

function DeterministicStandard(name, resolution, data, scaling_factor_multiplier=nothing, )
    DeterministicStandard(name, resolution, data, scaling_factor_multiplier, InfrastructureSystemsInternal(), )
end

function DeterministicStandard(; name, resolution, data, scaling_factor_multiplier=nothing, internal=InfrastructureSystemsInternal(), )
    DeterministicStandard(name, resolution, data, scaling_factor_multiplier, internal, )
end

"""Get [`DeterministicStandard`](@ref) `name`."""
get_name(value::DeterministicStandard) = value.name
"""Get [`DeterministicStandard`](@ref) `resolution`."""
get_resolution(value::DeterministicStandard) = value.resolution
"""Get [`DeterministicStandard`](@ref) `data`."""
get_data(value::DeterministicStandard) = value.data
"""Get [`DeterministicStandard`](@ref) `scaling_factor_multiplier`."""
get_scaling_factor_multiplier(value::DeterministicStandard) = value.scaling_factor_multiplier
"""Get [`DeterministicStandard`](@ref) `internal`."""
get_internal(value::DeterministicStandard) = value.internal

"""Set [`DeterministicStandard`](@ref) `name`."""
set_name!(value::DeterministicStandard, val) = value.name = val
"""Set [`DeterministicStandard`](@ref) `resolution`."""
set_resolution!(value::DeterministicStandard, val) = value.resolution = val
"""Set [`DeterministicStandard`](@ref) `data`."""
set_data!(value::DeterministicStandard, val) = value.data = val
"""Set [`DeterministicStandard`](@ref) `scaling_factor_multiplier`."""
set_scaling_factor_multiplier!(value::DeterministicStandard, val) = value.scaling_factor_multiplier = val
"""Set [`DeterministicStandard`](@ref) `internal`."""
set_internal!(value::DeterministicStandard, val) = value.internal = val

