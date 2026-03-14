@testset "TimeSeriesFunctionData" begin
    forecast_key = IS.ForecastKey(
        time_series_type = IS.Deterministic,
        name = "test_forecast",
        initial_timestamp = Dates.DateTime("2020-01-01"),
        resolution = Dates.Hour(1),
        horizon = Dates.Hour(24),
        interval = Dates.Hour(24),
        count = 1,
        features = Dict{String, Any}(),
    )

    ts_types = [
        IS.TimeSeriesLinearFunctionData,
        IS.TimeSeriesQuadraticFunctionData,
        IS.TimeSeriesPiecewiseLinearData,
        IS.TimeSeriesPiecewiseStepData,
    ]

    underlying_types = [
        IS.LinearFunctionData,
        IS.QuadraticFunctionData,
        IS.PiecewiseLinearData,
        IS.PiecewiseStepData,
    ]

    @testset "is_time_series_backed" begin
        for T in ts_types
            @test IS.is_time_series_backed(T(forecast_key)) == true
        end
        @test IS.is_time_series_backed(IS.LinearFunctionData(1.0, 2.0)) == false
        @test IS.is_time_series_backed(IS.QuadraticFunctionData(1.0, 2.0, 3.0)) == false
        @test IS.is_time_series_backed(
            IS.PiecewiseLinearData([(x = 1.0, y = 1.0), (x = 2.0, y = 2.0)]),
        ) == false
        @test IS.is_time_series_backed(
            IS.PiecewiseStepData([1.0, 2.0, 3.0], [1.0, 2.0]),
        ) == false
    end

    @testset "get_underlying_function_data_type" begin
        for (T, U) in zip(ts_types, underlying_types)
            @test IS.get_underlying_function_data_type(T) == U
            @test IS.get_underlying_function_data_type(T(forecast_key)) == U
        end
    end

    @testset "Serialization round-trip" begin
        for T in ts_types
            fd = T(forecast_key)
            serialized = IS.serialize(fd)
            deserialized = IS.deserialize(T, serialized)
            @test deserialized isa T
            deserialized_key = IS.get_time_series_key(deserialized)
            @test IS.get_name(deserialized_key) == IS.get_name(forecast_key)
            @test IS.get_resolution(deserialized_key) == IS.get_resolution(forecast_key)
        end
    end

    @testset "Show" begin
        for (T, U) in zip(ts_types, underlying_types)
            fd = T(forecast_key)
            str = sprint(show, MIME("text/plain"), fd)
            @test contains(str, "test_forecast")
            @test contains(str, string(U))
        end
    end

    @testset "Integration with time series storage" begin
        initial_time = Dates.DateTime("2020-01-01")
        resolution = Dates.Hour(1)
        horizon_count = 24
        name = "cost_data"

        # FunctionData vectors for each type, one element per timestep
        fd_vectors = Dict(
            IS.TimeSeriesLinearFunctionData => [
                IS.LinearFunctionData(Float64(i), Float64(i) + 1.0)
                for i in 1:horizon_count
            ],
            IS.TimeSeriesQuadraticFunctionData => [
                IS.QuadraticFunctionData(Float64(i), Float64(i) + 1.0, Float64(i) + 2.0)
                for i in 1:horizon_count
            ],
            IS.TimeSeriesPiecewiseLinearData => [
                IS.PiecewiseLinearData([
                    (x = Float64(i), y = Float64(i) + 1.0),
                    (x = Float64(i) + 2.0, y = Float64(i) + 5.0),
                    (x = Float64(i) + 4.0, y = Float64(i) + 10.0),
                ])
                for i in 1:horizon_count
            ],
            IS.TimeSeriesPiecewiseStepData => [
                IS.PiecewiseStepData(
                    [Float64(i), Float64(i) + 2.0, Float64(i) + 4.0],
                    [Float64(i) + 1.0, Float64(i) + 3.0],
                )
                for i in 1:horizon_count
            ],
        )

        for (TSType, fd_data) in fd_vectors
            @testset "$TSType" begin
                sys = IS.SystemData(; time_series_in_memory = true)
                component = IS.TestComponent("gen1", 5)
                IS.add_component!(sys, component)

                ts_data = SortedDict(initial_time => fd_data)
                forecast = IS.Deterministic(; data = ts_data, name = name,
                    resolution = resolution)
                key = IS.add_time_series!(sys, component, forecast)

                # Wrap the key in the corresponding TimeSeriesFunctionData
                ts_fd = TSType(key)
                @test IS.is_time_series_backed(ts_fd)
                @test IS.get_name(IS.get_time_series_key(ts_fd)) == name

                # Retrieve the time series using the key from the wrapper
                retrieved_key = IS.get_time_series_key(ts_fd)
                retrieved_ts = IS.get_time_series(
                    IS.Deterministic, component, name;
                    start_time = initial_time, len = horizon_count,
                    count = 1,
                )
                retrieved_data = first(values(IS.get_data(retrieved_ts)))
                @test length(retrieved_data) == horizon_count
                @test retrieved_data == fd_data

                # Verify the underlying type matches the stored data
                UnderlyingType = IS.get_underlying_function_data_type(TSType)
                @test eltype(retrieved_data) == UnderlyingType
            end
        end
    end

    @testset "HDF5 round-trip with TimeSeriesFunctionData key" begin
        initial_time = Dates.DateTime("2020-01-01")
        other_time = Dates.DateTime("2020-01-02")
        resolution = Dates.Hour(1)
        horizon_count = 3
        name = "cost_curve"

        # Test each FunctionData type through HDF5 serialization
        fd_test_cases = Dict(
            IS.TimeSeriesLinearFunctionData => [
                IS.LinearFunctionData(1.0, 2.0),
                IS.LinearFunctionData(3.0, 4.0),
                IS.LinearFunctionData(5.0, 6.0),
            ],
            IS.TimeSeriesQuadraticFunctionData => [
                IS.QuadraticFunctionData(1.0, 2.0, 3.0),
                IS.QuadraticFunctionData(4.0, 5.0, 6.0),
                IS.QuadraticFunctionData(7.0, 8.0, 9.0),
            ],
            IS.TimeSeriesPiecewiseLinearData => [
                IS.PiecewiseLinearData([(x = 1.0, y = 2.0), (x = 3.0, y = 6.0)]),
                IS.PiecewiseLinearData([(x = 2.0, y = 3.0), (x = 4.0, y = 7.0)]),
                IS.PiecewiseLinearData([(x = 3.0, y = 4.0), (x = 5.0, y = 8.0)]),
            ],
            IS.TimeSeriesPiecewiseStepData => [
                IS.PiecewiseStepData([1.0, 3.0, 5.0], [2.0, 4.0]),
                IS.PiecewiseStepData([2.0, 4.0, 6.0], [3.0, 5.0]),
                IS.PiecewiseStepData([3.0, 5.0, 7.0], [4.0, 6.0]),
            ],
        )

        fd_test_cases_2 = Dict(
            IS.TimeSeriesLinearFunctionData => [
                IS.LinearFunctionData(10.0, 20.0),
                IS.LinearFunctionData(30.0, 40.0),
                IS.LinearFunctionData(50.0, 60.0),
            ],
            IS.TimeSeriesQuadraticFunctionData => [
                IS.QuadraticFunctionData(10.0, 20.0, 30.0),
                IS.QuadraticFunctionData(40.0, 50.0, 60.0),
                IS.QuadraticFunctionData(70.0, 80.0, 90.0),
            ],
            IS.TimeSeriesPiecewiseLinearData => [
                IS.PiecewiseLinearData([(x = 10.0, y = 20.0), (x = 30.0, y = 60.0)]),
                IS.PiecewiseLinearData([(x = 20.0, y = 30.0), (x = 40.0, y = 70.0)]),
                IS.PiecewiseLinearData([(x = 30.0, y = 40.0), (x = 50.0, y = 80.0)]),
            ],
            IS.TimeSeriesPiecewiseStepData => [
                IS.PiecewiseStepData([10.0, 30.0, 50.0], [20.0, 40.0]),
                IS.PiecewiseStepData([20.0, 40.0, 60.0], [30.0, 50.0]),
                IS.PiecewiseStepData([30.0, 50.0, 70.0], [40.0, 60.0]),
            ],
        )

        for (TSType, fd_data) in fd_test_cases
            @testset "HDF5 $TSType" begin
                sys = IS.SystemData(; time_series_in_memory = false)
                component = IS.TestComponent("gen1", 5)
                IS.add_component!(sys, component)

                ts_data = SortedDict(
                    initial_time => fd_data,
                    other_time => fd_test_cases_2[TSType],
                )
                forecast = IS.Deterministic(; data = ts_data, name = name,
                    resolution = resolution)
                key = IS.add_time_series!(sys, component, forecast)

                # Create TimeSeriesFunctionData from the key
                ts_fd = TSType(key)
                retrieved_key = IS.get_time_series_key(ts_fd)

                # Retrieve the first window and verify data survived HDF5 round-trip
                retrieved_ts = IS.get_time_series(
                    IS.Deterministic, component, name;
                    start_time = initial_time, len = horizon_count,
                    count = 1,
                )
                retrieved_values = first(values(IS.get_data(retrieved_ts)))
                @test retrieved_values == fd_data

                # Retrieve the second window
                retrieved_ts_2 = IS.get_time_series(
                    IS.Deterministic, component, name;
                    start_time = other_time, len = horizon_count,
                    count = 1,
                )
                retrieved_values_2 = first(values(IS.get_data(retrieved_ts_2)))
                @test retrieved_values_2 == fd_test_cases_2[TSType]
            end
        end
    end
end
