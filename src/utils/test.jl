mutable struct TestComponent <: InfrastructureSystemsComponent
    name::String
    val::Int
    val2::Int
    internal::InfrastructureSystemsInternal
end

function TestComponent(name, val; val2 = 0)
    return TestComponent(
        name,
        val,
        val2,
        InfrastructureSystemsInternal(),
    )
end

mutable struct AdditionalTestComponent <: InfrastructureSystemsComponent
    name::String
    val::Int
    internal::InfrastructureSystemsInternal
end

function AdditionalTestComponent(name, val)
    return AdditionalTestComponent(
        name,
        val,
        InfrastructureSystemsInternal(),
    )
end

mutable struct SimpleTestComponent <: InfrastructureSystemsComponent
    name::String
    val::Int
    internal::InfrastructureSystemsInternal
end

function SimpleTestComponent(name, val)
    return SimpleTestComponent(name, val, InfrastructureSystemsInternal())
end

function SimpleTestComponent(; name, val, internal = InfrastructureSystemsInternal())
    return SimpleTestComponent(name, val, internal)
end

get_internal(component::TestComponent) = component.internal
get_internal(component::AdditionalTestComponent) = component.internal
get_val(component::TestComponent) = component.val
get_val2(component::TestComponent) = component.val2
supports_time_series(::TestComponent) = true
supports_time_series(::AdditionalTestComponent) = true
supports_time_series(::SimpleTestComponent) = false

function from_json(io::IO, ::Type{TestComponent})
    data = JSON3.read(io, Dict)
    return deserialize(TestComponent, data)
end

function deserialize(::Type{TestComponent}, data::Dict)
    return TestComponent(
        data["name"],
        data["val"],
        data["val2"],
        deserialize(InfrastructureSystemsInternal, data["internal"]),
    )
end

struct TestEvent <: AbstractRecorderEvent
    common::RecorderEventCommon
    val1::String
    val2::Int
    val3::Float64
end

function TestEvent(val1::String, val2::Int, val3::Float64)
    return TestEvent(RecorderEventCommon("TestEvent"), val1, val2, val3)
end

struct TestEvent2 <: AbstractRecorderEvent
    common::RecorderEventCommon
    val::Int
end

function TestEvent2(val::Int)
    return TestEvent2(RecorderEventCommon("TestEvent2"), val)
end

struct TestSupplemental <: SupplementalAttribute
    value::Float64
    internal::InfrastructureSystemsInternal
end

function TestSupplemental(;
    value::Float64,
    internal::InfrastructureSystemsInternal = InfrastructureSystemsInternal(),
)
    return TestSupplemental(value, internal)
end

supports_time_series(::TestSupplemental) = true
get_value(attr::TestSupplemental) = attr.attr_json
get_internal(attr::TestSupplemental) = attr.internal
get_uuid(attr::TestSupplemental) = get_uuid(get_internal(attr))
