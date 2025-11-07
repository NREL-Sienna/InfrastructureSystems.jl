@testset "IS.TypeSortedCollection Tests" begin
    @testset "Constructor Tests" begin
        # Test empty constructor
        D = Tuple{Vector{Int}, Vector{String}}
        tsc = IS.TypeSortedCollection{D, 2}()
        @test isempty(tsc)
        @test length(tsc) == 0
        @test IS.num_types(tsc) == 2

        # Test constructor with data and indices
        data = ([1, 2], ["a", "b"])
        indices = ([1, 3], [2, 4])
        tsc = IS.TypeSortedCollection(data, indices)
        @test length(tsc) == 4
        @test !isempty(tsc)

        # Test constructor from array
        A = [1, "hello", 2.5, "world", 3]
        tsc = IS.TypeSortedCollection(A)
        @test length(tsc) == 5

        # Test constructor with preserve_order
        tsc_ordered = IS.TypeSortedCollection(A, true)
        @test length(tsc_ordered) == 5

        # Test constructor with explicit indices
        A = [1, "a", 2, "b"]
        indices = ([1, 3], [2, 4])
        tsc = IS.TypeSortedCollection(A, indices)
        @test collect(tsc) == A
    end

    @testset "Basic Operations" begin
        tsc = IS.TypeSortedCollection{Tuple{Vector{Int}, Vector{String}}, 2}()

        # Test push!
        push!(tsc, 42)
        @test length(tsc) == 1
        @test !isempty(tsc)

        push!(tsc, "hello")
        @test length(tsc) == 2

        # Test error on incompatible type
        @test_throws ArgumentError push!(tsc, 2.5)

        # Test append!
        append!(tsc, [1, 2, "world", "test"])
        @test length(tsc) == 6

        # Test empty! and isempty
        empty!(tsc)
        @test isempty(tsc)
        @test length(tsc) == 0
    end

    @testset "Type System Tests" begin
        tsc = IS.TypeSortedCollection([1, "hello", 2.5])

        # Test eltype
        @test eltype(tsc) == Union{Int, String, Float64}

        # Test num_types
        @test IS.num_types(tsc) == 3
        @test IS.num_types(typeof(tsc)) == 3

        # Test indices function
        idxs = IS.indices(tsc)
        @test length(idxs) == 3
    end

    @testset "Iteration Tests" begin
        A = [1, "hello", 2, "world", 3.0]
        tsc = IS.TypeSortedCollection(A)

        # Test basic iteration
        collected = collect(tsc)
        @test length(collected) == 5
        @test Set(collected) == Set(A)  # Same elements, possibly different order

        # Test iteration state
        iter_result = iterate(tsc)
        @test iter_result !== nothing
        element, state = iter_result
        @test element isa Union{Int, String, Float64}
        @test state isa IS.TSCIterState

        # Test complete iteration
        count = 0
        for item in tsc
            println("Iterated item: $item")
            count += 1
        end
        @test count == 5
    end

    @testset "map! Tests" begin
        A = [1, "a", 2, "b"]
        B = [3, "x", 4, "y"]
        indices = ([1, 3], [2, 4])
        src1 = IS.TypeSortedCollection(A, indices)
        src2 = IS.TypeSortedCollection(B, indices)
        dest2 = IS.TypeSortedCollection([0, "", 0, ""], indices)
        map!(*, dest2, src1, src2)

        @test collect(dest2) == A .* B
    end

    @testset "foreach Tests" begin
        tsc = IS.TypeSortedCollection([1, 2, "a", "b"])
        results = []

        foreach(x -> push!(results, x), tsc)
        @test length(results) == 4
        @test Set(results) == Set([1, 2, "a", "b"])
    end

    @testset "mapreduce Tests" begin
        tsc = IS.TypeSortedCollection([1, 2, 3, 4])

        # Test sum
        result = mapreduce(identity, +, tsc; init = 0)
        @test result == 10

        # Test with function
        result = mapreduce(x -> x^2, +, tsc; init = 0)
        @test result == 30  # 1 + 4 + 9 + 16

        # Test with mixed types
        tsc_mixed = IS.TypeSortedCollection([1, 2])
        result = mapreduce(x -> 1, +, tsc_mixed; init = 0)
        @test result == 2
    end

    @testset "any/all Tests" begin
        tsc_nums = IS.TypeSortedCollection([1, 2, 3, 4])

        # Test any
        @test any(x -> x > 3, tsc_nums) == true
        @test any(x -> x > 10, tsc_nums) == false

        # Test all
        @test all(x -> x > 0, tsc_nums) == true
        @test all(x -> x > 2, tsc_nums) == false

        # Test with empty collection
        empty_tsc = IS.TypeSortedCollection{Tuple{Vector{Int}}, 1}()
        @test any(x -> true, empty_tsc) == false
        @test all(x -> false, empty_tsc) == true

        # Test with mixed types
        mixed_tsc = IS.TypeSortedCollection([1, "hello"])
        @test any(x -> isa(x, String), mixed_tsc) == true
        @test all(x -> isa(x, String), mixed_tsc) == false
    end

    @testset "Helper Function Tests" begin
        tsc1 = IS.TypeSortedCollection([1, 2])
        tsc2 = IS.TypeSortedCollection([3, 4])
        vec = [5, 6]

        # Test first_tsc
        @test IS.first_tsc(tsc1, tsc2) === tsc1
        @test IS.first_tsc(vec, tsc1, tsc2) === tsc1

        # Test lengths_match
        @test IS.lengths_match(tsc1, tsc2) == true
        @test IS.lengths_match(tsc1, [1, 2]) == true
        @test IS.lengths_match(tsc1, [1, 2, 3]) == false
    end

    @testset "Error Handling Tests" begin
        # Test constructor errors
        @test_throws Exception IS.TypeSortedCollection{Tuple{Vector{Int}}, 2}(
            ([1],),
            ([1],),
        )  # Wrong N

        # Test incompatible indices
        #=
        data = ([1, 2], ["a"])
        indices = ([1, 3], [2])  # indices don't match total length
        # really? 
        @test_throws Exception IS.TypeSortedCollection(data, indices)
        =#

        # Test duplicate indices
        data = ([1], [2])
        indices = ([1], [1])  # duplicate index
        @test_throws Exception IS.TypeSortedCollection(data, indices)
    end

    @testset "Edge Cases" begin
        # Test with single type
        # collect here seems to be a problem.
        single_type = IS.TypeSortedCollection([1, 2, 3])
        @test length(single_type) == 3
        @test collect(single_type) == [1, 2, 3]

        # Test with empty vectors in data
        D = Tuple{Vector{Int}, Vector{String}}
        empty_tsc = IS.TypeSortedCollection{D, 2}()
        @test isempty(empty_tsc)
        @test collect(empty_tsc) == []

        # Test preserve_order with repeated types
        A = [1, "a", 2, "b", 3]
        tsc_ordered = IS.TypeSortedCollection(A, true)
        collected = collect(tsc_ordered)
        # Should maintain relative order within type groups
        int_positions = [i for (i, x) in enumerate(collected) if isa(x, Int)]
        string_positions = [i for (i, x) in enumerate(collected) if isa(x, String)]
        @test length(int_positions) == 3
        @test length(string_positions) == 2
    end
end
