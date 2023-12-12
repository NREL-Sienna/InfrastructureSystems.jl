
mutable struct TestComponent <: InfrastructureSystemsComponent
    name::String
    val::Int
    time_series_container::TimeSeriesContainer
    attributes_container::SupplementalAttributesContainer
    internal::InfrastructureSystemsInternal
end

mutable struct AdditionalTestComponent <: InfrastructureSystemsComponent
    name::String
    val::Int
    time_series_container::TimeSeriesContainer
    attributes_container::SupplementalAttributesContainer
    internal::InfrastructureSystemsInternal
end

function TestComponent(name, val)
    return TestComponent(
        name,
        val,
        TimeSeriesContainer(),
        SupplementalAttributesContainer(),
        InfrastructureSystemsInternal(),
    )
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

get_internal(component::TestComponent) = component.internal
get_internal(component::AdditionalTestComponent) = component.internal
get_val(component::TestComponent) = component.val
get_supplemental_attributes_container(component::TestComponent) =
    component.attributes_container
get_supplemental_attributes_container(component::AdditionalTestComponent) =
    component.attributes_container

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
        deserialize(TimeSeriesContainer, data["time_series_container"]),
        SupplementalAttributesContainer(),
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

function runtests(args...)
    test_prefix = "test_"
    for arg in args
        if !startswith(arg, test_prefix)
            arg = test_prefix * arg
        end
        push!(ARGS, arg)
    end

    try
        include("test/runtests.jl")
    finally
        empty!(ARGS)
    end
end
