@testset "Test assign_new_uuid_internal" begin
    component = IS.TestComponent("component", 5)
    uuid1 = IS.get_uuid(component)
    IS.assign_new_uuid_internal!(component)
    @test uuid1 != IS.get_uuid(component)
end

@testset "Test ext" begin
    internal = IS.InfrastructureSystemsInternal()
    @test isnothing(internal.ext)
    ext = IS.get_ext(internal)
    ext["my_value"] = 1
    @test IS.get_ext(internal)["my_value"] == 1

    internal2 = IS.deserialize(IS.InfrastructureSystemsInternal, IS.serialize(internal))
    @test internal.uuid == internal2.uuid
    @test internal.ext == internal2.ext

    IS.clear_ext!(internal)
    @test isnothing(internal.ext)
end
