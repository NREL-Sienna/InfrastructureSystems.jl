mutable struct TestComponent <: InfrastructureSystemsComponent
    name::String
    val::Int
    val2::Int
    time_series_container::TimeSeriesContainer
    supplemental_attributes_container::SupplementalAttributesContainer
    internal::InfrastructureSystemsInternal
end

function TestComponent(name, val; val2 = 0)
    return TestComponent(
        name,
        val,
        val2,
        TimeSeriesContainer(),
        SupplementalAttributesContainer(),
        InfrastructureSystemsInternal(),
    )
end

mutable struct AdditionalTestComponent <: InfrastructureSystemsComponent
    name::String
    val::Int
    time_series_container::TimeSeriesContainer
    supplemental_attributes_container::SupplementalAttributesContainer
    internal::InfrastructureSystemsInternal
end

function AdditionalTestComponent(name, val)
    return AdditionalTestComponent(
        name,
        val,
        TimeSeriesContainer(),
        SupplementalAttributesContainer(),
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
get_supplemental_attributes_container(component::TestComponent) =
    component.supplemental_attributes_container
get_supplemental_attributes_container(component::AdditionalTestComponent) =
    component.supplemental_attributes_container

function get_time_series_container(component::TestComponent)
    return component.time_series_container
end

function from_json(io::IO, ::Type{TestComponent})
    data = JSON3.read(io, Dict)
    return deserialize(TestComponent, data)
end

function deserialize(::Type{TestComponent}, data::Dict)
    return TestComponent(
        data["name"],
        data["val"],
        data["val2"],
        deserialize(TimeSeriesContainer, data["time_series_container"]),
        data["supplemental_attributes_container"],
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
    component_uuids::ComponentUUIDs
    internal::InfrastructureSystemsInternal
    time_series_container::TimeSeriesContainer
end

function TestSupplemental(;
    value::Float64,
    component_uuids::ComponentUUIDs = ComponentUUIDs(),
    time_series_container = TimeSeriesContainer(),
    internal::InfrastructureSystemsInternal = InfrastructureSystemsInternal(),
)
    return TestSupplemental(
        value,
        component_uuids,
        internal,
        time_series_container,
    )
end

get_value(attr::TestSupplemental) = attr.attr_json
get_internal(attr::TestSupplemental) = attr.internal
get_uuid(attr::TestSupplemental) = get_uuid(get_internal(attr))
get_component_uuids(attr::TestSupplemental) = attr.component_uuids
get_time_series_container(attr::TestSupplemental) = attr.time_series_container
