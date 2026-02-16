@testset "Test assert_op" begin
    a = 2
    b = 2
    IS.@assert_op a == b
    IS.@assert_op a + 2 == b + 2
    IS.@assert_op isequal(a + 2, b + 2)

    @test_throws AssertionError IS.@assert_op a + 3 == b + 2
    @test_throws AssertionError IS.@assert_op isequal(a + 3, b + 2)
end

abstract type MyType end
struct SubtypeOne <: MyType end
struct SubtypeTwo <: MyType end

@testset "Test assert_op with custom types" begin
    @noinline function type_param_fcn(::T) where {T <: MyType}
        IS.@assert_op T <: SubtypeOne
    end
    type_param_fcn(SubtypeOne())
    @test_throws AssertionError type_param_fcn(SubtypeTwo())
end
