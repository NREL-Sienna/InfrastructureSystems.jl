@testset "Test ext" begin
    internal = IS.InfrastructureSystemsInternal()
    @test isnothing(internal.ext)
    ext = IS.get_ext(internal)
    ext["my_value"] = 1
    @test IS.get_ext(internal)["my_value"] == 1

    internal2 = JSON2.read(JSON2.write(internal), IS.InfrastructureSystemsInternal)
    @test internal.uuid == internal2.uuid
    @test internal.ext == internal2.ext
end
