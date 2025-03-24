@testset "Test check_resolution" begin
    timestamps = [
        DateTime("2023-01-01T00:00:00"),
        DateTime("2023-01-01T00:01:00"),
        DateTime("2023-01-01T00:02:00"),
        DateTime("2023-01-01T00:03:00"),
    ]
    resolution = Minute(1)
    IS.check_resolution(timestamps, resolution)

    timestamps = [
        DateTime("2023-01-01T00:00:00"),
        DateTime("2023-01-01T00:01:00"),
        DateTime("2023-01-01T00:02:00"),
        DateTime("2023-01-01T00:04:00"),
    ]
    resolution = Minute(1)
    @test_throws IS.ConflictingInputsError IS.check_resolution(timestamps, resolution)

    timestamps = [
        DateTime("2023-01-01T00:00:00"),
        DateTime("2023-02-01T00:00:00"),
        DateTime("2023-03-01T00:00:00"),
        DateTime("2023-04-01T00:00:00"),
    ]
    resolution = Month(1)
    IS.check_resolution(timestamps, resolution)

    timestamps = [
        DateTime("2023-01-01T00:00:00"),
        DateTime("2023-02-01T00:00:00"),
        DateTime("2023-03-01T00:00:00"),
        DateTime("2023-04-02T00:00:00"),
    ]
    resolution = Month(1)
    @test_throws IS.ConflictingInputsError IS.check_resolution(timestamps, resolution)
end

@testset "Test get_resolution" begin
    timestamps = [
        DateTime("2023-01-01T00:00:00"),
        DateTime("2023-01-01T00:01:00"),
        DateTime("2023-01-01T00:02:00"),
        DateTime("2023-01-01T00:03:00"),
    ]
    ts = TimeSeries.TimeArray(timestamps, rand(length(timestamps)))
    @test IS.get_resolution(ts) == Minute(1)

    timestamps = [
        DateTime("2023-01-01T00:00:00"),
        DateTime("2023-02-01T00:00:00"),
        DateTime("2023-03-01T00:00:00"),
        DateTime("2023-04-01T00:00:00"),
    ]
    ts = TimeSeries.TimeArray(timestamps, rand(length(timestamps)))
    @test IS.get_resolution(ts) != Month(1)

    timestamps = [
        DateTime("2023-01-01T00:00:00"),
    ]
    ts = TimeSeries.TimeArray(timestamps, rand(length(timestamps)))
    @test_throws IS.ConflictingInputsError IS.get_resolution(ts)
end

@testset "Test period to_string" begin
    @test IS.from_string(IS.to_string(Hour(1))) == Hour(1)
    @test IS.from_string(IS.to_string(Minute(5))) == Minute(5)
    @test IS.from_string(IS.to_string(Month(1))) == Month(1)
end

@testset "Test is_constant_period" begin
    all_periods = Set(IS.get_all_concrete_subtypes(Period))
    constant_periods = (
        Day,
        Week,
        Hour,
        Microsecond,
        Millisecond,
        Minute,
        Nanosecond,
        Second,
    )
    non_constant_periods = (
        Month,
        Quarter,
        Year,
    )

    # Ensure that we find out about new Period types.
    @test isempty(setdiff(all_periods, union(constant_periods, non_constant_periods)))

    for period_type in constant_periods
        @test IS.is_constant_period(period_type(5))
    end
    for period_type in non_constant_periods
        @test !IS.is_constant_period(period_type(5))
    end
end

@testset "Test compute_time_array_index" begin
    @test IS.compute_time_array_index(
        DateTime(2024, 1, 1),
        DateTime(2024, 1, 2),
        Minute(5),
    ) == 289
    @test IS.compute_time_array_index(
        DateTime(2024, 1, 1),
        DateTime(2024, 1, 1, 5),
        Hour(1),
    ) == 6
    @test IS.compute_time_array_index(
        DateTime(2024, 1, 1),
        DateTime(2024, 12, 1),
        Month(1),
    ) == 12
    @test IS.compute_time_array_index(
        DateTime(2024, 1, 1),
        DateTime(2025, 1, 1),
        Month(2),
    ) == 7
    @test IS.compute_time_array_index(
        DateTime(2024, 1, 1),
        DateTime(2024, 10, 1),
        Quarter(1),
    ) == 4
    @test IS.compute_time_array_index(
        DateTime(2024, 1, 1),
        DateTime(2034, 1, 1),
        Year(1),
    ) == 11

    @test_throws ArgumentError IS.compute_time_array_index(
        DateTime(2024, 1, 1),
        DateTime(2024, 1, 1, 5, 30),
        Hour(1),
    ) == 6
end
