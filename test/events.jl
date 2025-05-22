struct TestEvent <: IS.AbstractRecorderEvent
    common::IS.RecorderEventCommon
    val1::String
    val2::Int
    val3::Float64
end

function TestEvent(val1::String, val2::Int, val3::Float64)
    return TestEvent(IS.RecorderEventCommon("TestEvent"), val1, val2, val3)
end

struct TestEvent2 <: IS.AbstractRecorderEvent
    common::IS.RecorderEventCommon
    val::Int
end

function TestEvent2(val::Int)
    return TestEvent2(IS.RecorderEventCommon("TestEvent2"), val)
end
