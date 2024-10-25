
function run_test(T, a, b)
    c = [values(a), values(b)]
    len = length(a) + length(b)
    iter = IS.FlattenIteratorWrapper(T, c)
    @test length(iter) == len
    @test eltype(iter) == T

    i = 0
    for x in iter
        i += 1
    end
    @test i == len
end

@testset "Test IS.FlattenIteratorWrapper dictionaries" begin
    run_test(Int, Dict("1" => 1, "2" => 2, "3" => 3), Dict("4" => 4, "5" => 5, "6" => 6))
    run_test(Int, Dict{String, Int}(), Dict{String, Int}())
end

@testset "Test IS.FlattenIteratorWrapper vectors" begin
    run_test(Int, [1, 2, 3], [4, 5, 6])
    run_test(Int, [], [])
end

@testset "Test filter(..., ::IS.FlattenIteratorWrapper)" begin
    iter = IS.FlattenIteratorWrapper(Integer, [[1, 2, 3, 4, 5, 6]])
    @test filter(iseven, iter) isa IS.FlattenIteratorWrapper{Integer}
    @test collect(filter(iseven, iter)) == [2, 4, 6]
    @test filter(<(0), iter) isa IS.FlattenIteratorWrapper{Integer}
    @test collect(filter(<(0), iter)) == []
end
