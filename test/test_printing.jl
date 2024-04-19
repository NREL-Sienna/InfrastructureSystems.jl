@testset "Test printing of the system and components" begin
    sys = create_system_data(; with_time_series = true, time_series_in_memory = true)
    io = IOBuffer()
    show(io, "text/plain", sys)
    text = String(take!(io))
    @test occursin("TestComponent", text)
    @test occursin("time_series_type", text)
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

    component = first(IS.get_components(IS.TestComponent, sys))
    @test IS.has_time_series(component)
    io = IOBuffer()
    IS.show_time_series(io, component)
    text = String(take!(io))
    @test occursin("SingleTimeSeries", text)
end
