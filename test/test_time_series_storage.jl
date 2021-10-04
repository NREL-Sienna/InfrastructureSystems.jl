
function make_metadata(ts::IS.TimeSeriesData)
    return IS.time_series_data_to_metadata(typeof(ts))(ts)
end

"""
Helper function that gets all values and then deserializes a full object.
"""
function _deserialize_full(storage, ts)
    ts_metadata = make_metadata(ts)
    return IS.deserialize_time_series(
        IS.SingleTimeSeries,
        storage,
        ts_metadata,
        UnitRange(1, length(ts)),
        UnitRange(1, 1),
    )
end

function test_add_remove(storage::IS.TimeSeriesStorage)
    name = "component1"
    name = "val"
    component = IS.TestComponent(name, 5)
    ts = IS.SingleTimeSeries(data = create_time_array(), name = "test")
    IS.serialize_time_series!(storage, IS.get_uuid(component), name, ts)

    ts2 = _deserialize_full(storage, ts)
    @test TimeSeries.timestamp(IS.get_data(ts2)) == TimeSeries.timestamp(IS.get_data(ts))
    @test TimeSeries.values(IS.get_data(ts2)) == TimeSeries.values(IS.get_data(ts))

    component2 = IS.TestComponent("component2", 6)
    IS.serialize_time_series!(storage, IS.get_uuid(component2), name, ts)

    @test IS.get_num_time_series(storage) == 1

    IS.remove_time_series!(storage, IS.get_uuid(ts), IS.get_uuid(component2), name)

    ## There should still be one reference to the data.
    ts2 = _deserialize_full(storage, ts)
    @test IS.get_data(ts2) isa TimeSeries.TimeArray

    IS.remove_time_series!(storage, IS.get_uuid(ts), IS.get_uuid(component), name)
    @test_throws ArgumentError _deserialize_full(storage, ts)
    return IS.get_num_time_series(storage) == 0
end

function test_add_references(storage::IS.TimeSeriesStorage)
    name = "val"
    component1 = IS.TestComponent("component1", 5)
    component2 = IS.TestComponent("component2", 6)
    ts = IS.SingleTimeSeries(data = create_time_array(), name = "test")
    ts_uuid = IS.get_uuid(ts)
    IS.serialize_time_series!(storage, IS.get_uuid(component1), name, ts)
    IS.add_time_series_reference!(storage, IS.get_uuid(component2), name, ts_uuid)

    # Adding duplicate references is not allowed.
    @test_throws AssertionError IS.add_time_series_reference!(
        storage,
        IS.get_uuid(component2),
        name,
        ts_uuid,
    )

    @test IS.get_num_time_series(storage) == 1

    IS.remove_time_series!(storage, ts_uuid, IS.get_uuid(component1), name)

    # There should still be one reference to the data.
    @test _deserialize_full(storage, ts) isa IS.TimeSeriesData

    IS.remove_time_series!(storage, ts_uuid, IS.get_uuid(component2), name)
    @test_throws ArgumentError _deserialize_full(storage, ts)
    return IS.get_num_time_series(storage) == 0
end

function test_get_subset(storage::IS.TimeSeriesStorage)
    name = "component1"
    name = "val"
    component = IS.TestComponent(name, 1)
    ts = IS.SingleTimeSeries(data = create_time_array(), name = "test")
    IS.serialize_time_series!(storage, IS.get_uuid(component), name, ts)
    ts2 = _deserialize_full(storage, ts)

    @test TimeSeries.timestamp(IS.get_data(ts2)) == TimeSeries.timestamp(IS.get_data(ts))
    rows = UnitRange(3, 8)
    columns = UnitRange(1, 1)
    ts_metadata = make_metadata(ts)
    ts_subset =
        IS.deserialize_time_series(IS.SingleTimeSeries, storage, ts_metadata, rows, columns)
    @test IS.get_data(ts_subset)[1] == IS.get_data(ts2)[rows.start]
    @test length(ts_subset) == length(rows)

    initial_time1 = Dates.DateTime("2020-09-01")
    resolution = Dates.Hour(1)
    initial_time2 = initial_time1 + resolution
    name = "test"
    horizon = 24
    data = SortedDict(initial_time1 => ones(horizon), initial_time2 => ones(horizon))

    ts = IS.Deterministic(data = data, name = name, resolution = resolution)
    IS.serialize_time_series!(storage, IS.get_uuid(component), name, ts)
    ts_metadata = make_metadata(ts)
    rows = UnitRange(1, horizon)
    columns = UnitRange(1, 2)
    ts2 = IS.deserialize_time_series(IS.Deterministic, storage, ts_metadata, rows, columns)
    @test collect(IS.get_initial_times(ts2)) == collect(IS.get_initial_times(ts))
    @test collect(IS.iterate_windows(ts2)) == collect(IS.iterate_windows(ts))

    rows = UnitRange(3, 8)
    columns = UnitRange(1, 2)
    ts_subset =
        IS.deserialize_time_series(IS.Deterministic, storage, ts_metadata, rows, columns)
    @test IS.get_horizon(ts_subset) == length(rows)
    @test IS.get_count(ts_subset) == columns.stop
    @test IS.get_initial_timestamp(ts_subset) ==
          initial_time1 + resolution * (rows.start - 1)

    rows = UnitRange(2, 7)
    columns = UnitRange(1, 1)
    ts_subset =
        IS.deserialize_time_series(IS.Deterministic, storage, ts_metadata, rows, columns)
    @test IS.get_horizon(ts_subset) == length(rows)
    @test IS.get_count(ts_subset) == columns.stop
    @test IS.get_initial_timestamp(ts_subset) ==
          initial_time1 + resolution * (rows.start - 1)
end

function test_clear(storage::IS.TimeSeriesStorage)
    name = "component1"
    name = "val"
    component = IS.TestComponent(name, 5)
    ts = IS.SingleTimeSeries(data = create_time_array(), name = "test")
    IS.serialize_time_series!(storage, IS.get_uuid(component), name, ts)

    ts2 = _deserialize_full(storage, ts)
    @test TimeSeries.timestamp(IS.get_data(ts2)) == TimeSeries.timestamp(IS.get_data(ts))
    @test TimeSeries.values(IS.get_data(ts2)) == TimeSeries.values(IS.get_data(ts))

    IS.clear_time_series!(storage)
    @test_throws ArgumentError _deserialize_full(storage, ts)
end

@testset "Test time series storage implementations" begin
    for in_memory in (true, false)
        test_add_remove(IS.make_time_series_storage(; in_memory = in_memory))
        test_get_subset(IS.make_time_series_storage(; in_memory = in_memory))
        test_clear(IS.make_time_series_storage(; in_memory = in_memory))
    end

    test_add_remove(IS.make_time_series_storage(; in_memory = false, directory = "."))
    test_get_subset(IS.make_time_series_storage(; in_memory = false, directory = "."))
    test_clear(IS.make_time_series_storage(; in_memory = false, directory = "."))
end

@testset "Test copy time series references" begin
    for in_memory in (true, false)
        test_add_remove(IS.make_time_series_storage(; in_memory = in_memory))
        test_add_references(IS.make_time_series_storage(; in_memory = in_memory))
        test_get_subset(IS.make_time_series_storage(; in_memory = in_memory))
        test_clear(IS.make_time_series_storage(; in_memory = in_memory))
    end
end

@testset "Test data format version" begin
    storage = IS.make_time_series_storage(in_memory = false)
    @test IS.read_data_format_version(storage) == IS.TIME_SERIES_DATA_FORMAT_VERSION
end

@testset "Test compression" begin
    in_memory = false
    for type in (IS.CompressionTypes.BLOSC, IS.CompressionTypes.DEFLATE)
        for shuffle in (true, false)
            compression = IS.CompressionSettings(
                enabled = true,
                type = type,
                level = 5,
                shuffle = shuffle,
            )
            test_add_remove(
                IS.make_time_series_storage(;
                    in_memory = in_memory,
                    compression = compression,
                ),
            )
            test_add_references(
                IS.make_time_series_storage(;
                    in_memory = in_memory,
                    compression = compression,
                ),
            )
            test_get_subset(
                IS.make_time_series_storage(;
                    in_memory = in_memory,
                    compression = compression,
                ),
            )
            test_clear(
                IS.make_time_series_storage(;
                    in_memory = in_memory,
                    compression = compression,
                ),
            )
        end
    end
end

@testset "Test isempty" begin
    for in_memory in (true, false)
        storage = IS.make_time_series_storage(in_memory = in_memory)
        @test isempty(storage)
        name = "component1"
        name = "val"
        component = IS.TestComponent(name, 5)
        ts = IS.SingleTimeSeries(data = create_time_array(), name = "test")
        IS.serialize_time_series!(storage, IS.get_uuid(component), name, ts)
        @test !isempty(storage)
    end
end
