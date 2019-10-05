
@testset "Create time series data" begin
    ts = create_time_series_data()
    @test ts.data isa TimeSeries.TimeArray
    @test IS.get_initial_time(ts) isa Dates.DateTime
    @test IS.get_horizon(ts) == 24
    @test IS.get_resolution(ts) == Dates.Hour(1)
    @test IS.get_uuid(ts) isa UUIDs.UUID
    Base.show(devnull, ts)
end
