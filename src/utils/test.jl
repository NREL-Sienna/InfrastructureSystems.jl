
struct TestComponent <: InfrastructureSystemsType
    name::AbstractString
    val::Int
    forecasts::Forecasts
    internal::InfrastructureSystemsInternal
end

struct AdditionalTestComponent <: InfrastructureSystemsType
    name::AbstractString
    val::Int
    forecasts::Forecasts
    internal::InfrastructureSystemsInternal
end


function TestComponent(name, val)
    return TestComponent(name, val, Forecasts(), InfrastructureSystemsInternal())
end

function AdditionalTestComponent(name, val)
    return AdditionalTestComponent(name, val, Forecasts(), InfrastructureSystemsInternal())
end


get_val(component::TestComponent) = component.val

function get_forecasts(component::TestComponent)
    return component.forecasts
end

function JSON2.read(io::IO, ::Type{TestComponent})
    data = JSON2.read(io)
    return TestComponent(
        data.name,
        data.val,
        convert_type(Forecasts, data.forecasts),
        JSON2.read(JSON2.write(data.internal), InfrastructureSystemsInternal),
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
