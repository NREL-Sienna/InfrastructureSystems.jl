
import UUIDs

abstract type UnitsData end

@scoped_enum(UnitSystem, SYSTEM_BASE = 0, DEVICE_BASE = 1, NATURAL_UNITS = 2,)

const _UNIT_SYSTEM_MAP = Dict(string(x) => x for x in instances(UnitSystem))

mutable struct SystemUnitsSettings <: UnitsData
    base_value::Float64
    unit_system::UnitSystem
end

function serialize(val::SystemUnitsSettings)
    return Dict("base_value" => val.base_value, "unit_system" => string(val.unit_system))
end

function deserialize(::Type{SystemUnitsSettings}, data::Dict)
    return SystemUnitsSettings(data["base_value"], _UNIT_SYSTEM_MAP[data["unit_system"]])
end

"""
Internal storage common to InfrastructureSystems types.
"""
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
    return
end

get_uuid(internal::InfrastructureSystemsInternal) = internal.uuid
set_uuid!(internal::InfrastructureSystemsInternal, uuid) = internal.uuid = uuid

get_units_info(internal::InfrastructureSystemsInternal) = internal.units_info
set_units_info!(internal::InfrastructureSystemsInternal, value) =
    internal.units_info = value

"""
Gets the UUID for any InfrastructureSystemsType.
"""
function get_uuid(obj::InfrastructureSystemsType)
    return get_internal(obj).uuid
end

"""
Assign a new UUID.
"""
function assign_new_uuid_internal!(obj::InfrastructureSystemsType)
    get_internal(obj).uuid = make_uuid()
    return
end

function serialize(internal::InfrastructureSystemsInternal)
    data = Dict{String, Any}()

    for field in fieldnames(InfrastructureSystemsInternal)
        val = getproperty(internal, field)
        # reset the units data since this is a struct related to the system the components is
        # added which is resolved later in the de-serialization.
        if val isa UnitsData
            val = nothing
        else
            val = serialize(val)
        end
        if field == :ext
            if !is_ext_valid_for_serialization(val)
                error(
                    "system or component with uuid=$(internal.uuid) has a value in ext " *
                    "that cannot be serialized",
                )
            end
        end
        data[string(field)] = val
    end

    return data
end

function compare_values(
    x::InfrastructureSystemsInternal,
    y::InfrastructureSystemsInternal;
    compare_uuids = false,
    exclude = Set{Symbol}(),
)
    match = true
    for name in fieldnames(InfrastructureSystemsInternal)
        if name in exclude || (name == :uuid && !compare_uuids)
            continue
        end
        if name == :ext
            val1 = getproperty(x, name)
            if val1 isa Dict && isempty(val1)
                val1 = nothing
            end
            val2 = getproperty(y, name)
            if val2 isa Dict && isempty(val2)
                val2 = nothing
            end
            if !compare_values(val1, val2; compare_uuids = compare_uuids, exclude = exclude)
                @error "ext does not match" val1 val2
                match = false
            end
        elseif !compare_values(
            getproperty(x, name),
            getproperty(y, name);
            compare_uuids = compare_uuids,
            exclude = exclude,
        )
            @error "InfrastructureSystemsInternal field=$name does not match"
            match = false
        end
    end

    return match
end

make_uuid() = UUIDs.uuid4()
