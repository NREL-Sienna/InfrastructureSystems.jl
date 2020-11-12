@testset "Test assert_op" begin
    a = 2
    b = 2
    IS.@assert_op a == b
    IS.@assert_op a + 2 == b + 2
    IS.@assert_op isequal(a + 2, b + 2)

    @test_throws AssertionError IS.@assert_op a + 3 == b + 2
    @test_throws AssertionError IS.@assert_op isequal(a + 3, b + 2)
end
