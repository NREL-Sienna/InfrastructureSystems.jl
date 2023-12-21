@testset "Test printing of the system and components" begin
    sys = create_system_data(; with_time_series = true, time_series_in_memory = true)
    io = IOBuffer()
    show(io, "text/plain", sys)
    text = String(take!(io))
    @test occursin("TestComponent", text)
    @test occursin("Time Series Summary", text)
end

@testset "Test show_component_tables" begin
    sys = create_system_data(; with_time_series = true, time_series_in_memory = true)
    io = IOBuffer()
    IS.show_components(io, sys.components, IS.TestComponent)
    @test occursin("TestComponent", String(take!(io)))

    IS.show_components(io, sys.components, IS.TestComponent, [:val])
    text = String(take!(io))
    @test occursin("TestComponent", text)
    @test occursin("val", text)

    IS.show_components(io, sys.components, IS.TestComponent, Dict("val" => x -> x.val * 10))
    text = String(take!(io))
    @test occursin("TestComponent", text)
    @test occursin("val", text)
end
