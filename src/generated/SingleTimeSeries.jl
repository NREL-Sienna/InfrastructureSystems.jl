#=
This file is auto-generated. Do not edit.
=#
"""
    mutable struct SingleTimeSeries <: StaticTimeSeries
        label::String
        data::TimeSeries.TimeArray
        scaling_factor_multiplier::Union{Nothing, Function}
        internal::InfrastructureSystemsInternal
    end

A deterministic forecast for a particular data field in a Component.

# Arguments
- `label::String`: user-defined label
- `data::TimeSeries.TimeArray`: timestamp - scalingfactor
- `scaling_factor_multiplier::Union{Nothing, Function}`: Applicable when the time series data are scaling factors. Called on the associated component to convert the values.
- `internal::InfrastructureSystemsInternal`
"""
mutable struct SingleTimeSeries <: StaticTimeSeries
    "user-defined label"
    label::String
    "timestamp - scalingfactor"
    data::TimeSeries.TimeArray
    "Applicable when the time series data are scaling factors. Called on the associated component to convert the values."
    scaling_factor_multiplier::Union{Nothing, Function}
    internal::InfrastructureSystemsInternal
end

function SingleTimeSeries(label, data, scaling_factor_multiplier=nothing, )
    SingleTimeSeries(label, data, scaling_factor_multiplier, InfrastructureSystemsInternal(), )
end

function SingleTimeSeries(; label, data, scaling_factor_multiplier=nothing, internal=InfrastructureSystemsInternal(), )
    SingleTimeSeries(label, data, scaling_factor_multiplier, internal, )
end

"""Get [`SingleTimeSeries`](@ref) `label`."""
get_label(value::SingleTimeSeries) = value.label
"""Get [`SingleTimeSeries`](@ref) `data`."""
get_data(value::SingleTimeSeries) = value.data
"""Get [`SingleTimeSeries`](@ref) `scaling_factor_multiplier`."""
get_scaling_factor_multiplier(value::SingleTimeSeries) = value.scaling_factor_multiplier
"""Get [`SingleTimeSeries`](@ref) `internal`."""
get_internal(value::SingleTimeSeries) = value.internal

"""Set [`SingleTimeSeries`](@ref) `label`."""
set_label!(value::SingleTimeSeries, val) = value.label = val
"""Set [`SingleTimeSeries`](@ref) `data`."""
set_data!(value::SingleTimeSeries, val) = value.data = val
"""Set [`SingleTimeSeries`](@ref) `scaling_factor_multiplier`."""
set_scaling_factor_multiplier!(value::SingleTimeSeries, val) = value.scaling_factor_multiplier = val
"""Set [`SingleTimeSeries`](@ref) `internal`."""
set_internal!(value::SingleTimeSeries, val) = value.internal = val

