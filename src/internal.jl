
import UUIDs

abstract type UnitsData end

@enum UnitSystem begin
    SYSTEM_BASE
    DEVICE_BASE
    NATURAL_UNITS
end

const _UNIT_SYSTEM_MAP = Dict(string(x) => x for x in instances(UnitSystem))

mutable struct SystemUnitsSettings <: UnitsData
    base_value::Float64
    unit_system::UnitSystem
end

function serialize(val::SystemUnitsSettings)
    Dict("base_value" => val.base_value, "unit_system" => string(val.unit_system))
end

function deserialize(::Type{SystemUnitsSettings}, data::Dict)
    SystemUnitsSettings(data["base_value"], _UNIT_SYSTEM_MAP[data["unit_system"]])
end

"""Internal storage common to InfrastructureSystems types."""
mutable struct InfrastructureSystemsInternal <: InfrastructureSystemsType
    uuid::Base.UUID
    units_info::Union{Nothing, UnitsData}
    ext::Union{Nothing, Dict{String, Any}}
end

"""
Creates InfrastructureSystemsInternal with a new UUID.
"""
InfrastructureSystemsInternal(; uuid = make_uuid(), units_info = nothing, ext = nothing) =
    InfrastructureSystemsInternal(uuid, units_info, ext)

"""
Creates InfrastructureSystemsInternal with an existing UUID.
"""
InfrastructureSystemsInternal(u::UUIDs.UUID) =
    InfrastructureSystemsInternal(u, nothing, nothing)

"""
Return a user-modifiable dictionary to store extra information.
"""
function get_ext(obj::InfrastructureSystemsInternal)
    if isnothing(obj.ext)
        obj.ext = Dict{String, Any}()
    end

    return obj.ext
end

"""
Clear any value stored in ext.
"""
function clear_ext!(obj::InfrastructureSystemsInternal)
    obj.ext = nothing
end

get_uuid(internal::InfrastructureSystemsInternal) = internal.uuid

"""
Gets the UUID for any InfrastructureSystemsType.
"""
function get_uuid(obj::InfrastructureSystemsType)
    return get_internal(obj).uuid
end

"""
Assign a new UUID.
"""
function assign_new_uuid!(obj::InfrastructureSystemsType)
    get_internal(obj).uuid = make_uuid()
end

function serialize(internal::InfrastructureSystemsInternal)
    data = Dict{String, Any}()

    for field in fieldnames(InfrastructureSystemsInternal)
        val = getfield(internal, field)
        # reset the units data since this is a struct related to the system the components is
        # added which is resolved later in the de-serialization.
        if val isa UnitsData
            val = nothing
        else
            val = serialize(val)
        end
        data[string(field)] = val
    end

    return data
end

function compare_values(x::InfrastructureSystemsInternal, y::InfrastructureSystemsInternal)
    match = true
    for name in fieldnames(InfrastructureSystemsInternal)
        if name == :ext
            val1 = getfield(x, name)
            if val1 isa Dict && isempty(val1)
                val1 = nothing
            end
            val2 = getfield(y, name)
            if val2 isa Dict && isempty(val2)
                val2 = nothing
            end
            if !compare_values(val1, val2)
                @error "ext does not match" val1 val2
                match = false
            end
        elseif !compare_values(getfield(x, name), getfield(y, name))
            @error "InfrastructureSystemsInternal field=$name does not match"
            match = false
        end
    end

    return match
end

_RNG = Random.MersenneTwister()
make_uuid() = UUIDs.uuid4(_RNG)
