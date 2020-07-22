module TestModule

export TestModuleStruct
export TestModuleForwardStruct
export get_name
export get_val
export get_ext
export get_foo
import InfrastructureSystems
const IS = InfrastructureSystems

struct TestModuleStruct
    name::String
    val::Int
    ext::Dict{String, Any}
end

get_name(input::TestModuleStruct) = input.name
get_val(input::TestModuleStruct) = input.val
get_ext(input::TestModuleStruct) = input.ext

struct TestModuleForwardStruct
    is_test_struct::TestModuleStruct
    foo::Float64
end

get_foo(input::TestModuleForwardStruct) = input.foo

function TestModuleForwardStruct(a::Float64, b::Int)
    IS.@forward((TestModuleForwardStruct, :is_test_struct), TestModuleStruct, [:get_ext])
    return TestModuleForwardStruct(TestModuleStruct("meh", b, Dict{String, Any}()), a)
end

end
