# TEST HELPER FUNCTIONS
# Put `data` through `transform_array_for_hdf` and `retransform_hdf_array` and compare the results to `compare_to`
function _test_inner_round_trip_common(
    data::Union{Vector{T}, SortedDict{Dates.DateTime, <:Vector{T}}},
    compare_to,
) where {T}
    transformed = IS.transform_array_for_hdf(data)
    retransformed = IS.retransform_hdf_array(transformed, T)
    @test size(retransformed) == size(compare_to)  # Redundant but a more informative failure
    @test retransformed == compare_to
end

# For the dateless version, reconstituted data should be identical
test_inner_round_trip(data::Vector) = _test_inner_round_trip_common(data, data)

# For the dated version, reconstituted data lacks dates
test_inner_round_trip(data::SortedDict{Dates.DateTime, <:Vector}) =
    _test_inner_round_trip_common(data, hcat(values(data)...))

# Do a full serialization and deserialization to make sure subsetting works properly
function test_outer_round_trip(
    data::TimeSeries.TimeArray,
    storage::IS.TimeSeriesStorage,
    rows::UnitRange,
)
    ts = IS.SingleTimeSeries(; data = data, name = "test")
    ts_metadata = IS.SingleTimeSeriesMetadata(ts)
    IS.serialize_time_series!(storage, ts)
    ts_subset =
        IS.deserialize_time_series(IS.SingleTimeSeries, storage, ts_metadata, rows, 1:1)  # for SingleTimeSeries, only valid columns is 1:1
    @test length(ts_subset) == length(rows)
    @test IS.get_data(ts_subset) == IS.get_data(ts)[rows]
end

function test_outer_round_trip(
    data::SortedDict{Dates.DateTime, <:Vector},
    storage::IS.TimeSeriesStorage,
    rows::UnitRange,
    columns::UnitRange,
)
    resolution = -(collect(keys(data))[2:-1:1]...)
    ts = IS.Deterministic(; data = data, name = "test", resolution = resolution)
    ts_metadata = IS.DeterministicMetadata(ts)
    IS.serialize_time_series!(storage, ts)
    ts_subset =
        IS.deserialize_time_series(IS.Deterministic, storage, ts_metadata, rows, columns)
    @test IS.get_horizon_count(ts_subset) == length(rows)
    @test IS.get_count(ts_subset) == length(columns)
    @test collect(values(IS.get_data(ts_subset))) ==
          [sub[rows] for sub in collect(values(IS.get_data(ts)))[columns]]
end

# TEST DATA/RESOURCES
time_series_test_gen_storage() = IS.make_time_series_storage(; in_memory = true)

time_series_test_test_dates = [Dates.DateTime("2023-01-01"), Dates.DateTime("2024-01-01")]

time_series_test_gen_test_date_series(l) =
    collect(range(; start = Dates.Date("2024-01-01"), step = Dates.Day(1), length = l))

_gen_one_piecewise(::Type{IS.PiecewiseLinearData}, start_val, n_tranches) =
    IS.PiecewiseLinearData([
        (i + start_val, i + start_val + 3) for i::Float64 in 1:(n_tranches + 1)
    ])

_gen_one_piecewise(::Type{IS.PiecewiseStepData}, start_val, n_tranches) =
    IS.PiecewiseStepData(
        [i + start_val for i::Float64 in 1:(n_tranches + 1)],
        [i + start_val + 3 for i::Float64 in 1:n_tranches],
    )

"""
Generate a vector of piecewise `FunctionData` of type T. The vector has length `n_fds`, the
first piecewise `FunctionData` has `first_n_tranches` tranches (`length`), last has
`last_n_tranches`, rest have `rest_n_tranches`, values within the `FunctionData` start at
`start_val`.
"""
function time_series_test_gen_piecewise(
    ::Type{T},
    start_val,
    n_fds,
    first_n_tranches,
    last_n_tranches,
    rest_n_tranches,
) where {T <: IS.FunctionData}
    result = Vector{T}(undef, n_fds)
    for i in 1:n_fds
        my_n_tranches =
            (i == 1) ? first_n_tranches :
            ((i == n_fds) ? last_n_tranches : rest_n_tranches)
        result[i] = _gen_one_piecewise(T, start_val, my_n_tranches)
    end
    @assert length(result) == n_fds
    @assert length(first(result)) == first_n_tranches
    @assert length(last(result)) == last_n_tranches
    @assert all(length.(result[2:(end - 1)]) .== rest_n_tranches)
    return result
end

time_series_test_test_datas_1 = [
    [1.0, 2.0, 3.0],
    [(1.0, 2.0, 3.0), (4.0, 5.0, 6.0), (7.0, 8.0, 9.0), (10.0, 11.0, 12.0)],
    [
        IS.LinearFunctionData(1.0),
        IS.LinearFunctionData(2.0),
        IS.LinearFunctionData(3.0),
    ],
    [
        IS.LinearFunctionData(1.0, 7.0),
        IS.LinearFunctionData(2.0, 8.0),
        IS.LinearFunctionData(3.0, 9.0),
    ],
    [
        IS.QuadraticFunctionData(1.0, 2.0, 3.0),
        IS.QuadraticFunctionData(4.0, 5.0, 6.0),
        IS.QuadraticFunctionData(7.0, 8.0, 9.0),
        IS.QuadraticFunctionData(10.0, 11.0, 12.0),
    ],
    time_series_test_gen_piecewise(IS.PiecewiseLinearData, 0, 4, 4, 4, 4),
    time_series_test_gen_piecewise(IS.PiecewiseStepData, 0, 4, 4, 4, 4),
    time_series_test_gen_piecewise(IS.PiecewiseLinearData, 0, 4, 5, 4, 3),
    time_series_test_gen_piecewise(IS.PiecewiseStepData, 0, 4, 3, 4, 5),
]

time_series_test_test_datas_2 = [
    [4.0, 5.0, 6.0],
    [(21.0, 22.0, 23.0), (24.0, 25.0, 26.0), (27.0, 28.0, 29.0), (30.0, 31.0, 32.0)],
    [
        IS.LinearFunctionData(4.0),
        IS.LinearFunctionData(5.0),
        IS.LinearFunctionData(6.0),
    ],
    [
        IS.LinearFunctionData(1.0, 10.0),
        IS.LinearFunctionData(2.0, 11.0),
        IS.LinearFunctionData(3.0, 12.0),
    ],
    [
        IS.QuadraticFunctionData(21.0, 22.0, 23.0),
        IS.QuadraticFunctionData(24.0, 25.0, 26.0),
        IS.QuadraticFunctionData(27.0, 28.0, 29.0),
        IS.QuadraticFunctionData(30.0, 31.0, 32.0),
    ],
    time_series_test_gen_piecewise(IS.PiecewiseLinearData, 50, 4, 4, 4, 4),
    time_series_test_gen_piecewise(IS.PiecewiseStepData, 50, 4, 4, 4, 4),
    time_series_test_gen_piecewise(IS.PiecewiseLinearData, 50, 4, 5, 6, 3),
    time_series_test_gen_piecewise(IS.PiecewiseStepData, 50, 4, 3, 6, 5),
]

time_series_test_test_datas_dated = [
    SortedDict{Dates.DateTime, typeof(data_1)}(
        time_series_test_test_dates[1] => data_1,
        time_series_test_test_dates[2] => data_2)
    for (data_1, data_2) in
    zip(time_series_test_test_datas_1, time_series_test_test_datas_2)]

@testset "Test HDF transformation round trip: arrays" begin
    for test_data in time_series_test_test_datas_1
        test_inner_round_trip(test_data)
    end
end

@testset "Test HDF transformation round trip: SortedDict{DateTime}" begin
    for test_data in time_series_test_test_datas_dated
        test_inner_round_trip(test_data)
    end
end

@testset "Test HDF transformation round trip: SingleTimeSeries" begin
    for test_data in time_series_test_test_datas_1
        my_dates = time_series_test_gen_test_date_series(length(test_data))
        test_timearray = TimeSeries.TimeArray(my_dates, test_data)
        test_outer_round_trip(test_timearray, time_series_test_gen_storage(), 1:3)
        test_outer_round_trip(test_timearray, time_series_test_gen_storage(), 2:3)
    end
end

@testset "Test HDF transformation round trip: Deterministic" begin
    for test_data in time_series_test_test_datas_dated
        test_outer_round_trip(test_data, time_series_test_gen_storage(), 1:3, 1:2)
        test_outer_round_trip(test_data, time_series_test_gen_storage(), 2:3, 1:2)
        test_outer_round_trip(test_data, time_series_test_gen_storage(), 1:2, 2:2)
    end
end

@testset "Test error messages for non-concrete types" begin
    # Test Vector{Any} - should give informative error about non-concrete type
    # Using mixed types to illustrate when this occurs in practice
    data_any = Any[1.0, 2, 3.0]
    @test_throws ArgumentError IS.transform_array_for_hdf(data_any)
    try
        IS.transform_array_for_hdf(data_any)
    catch e
        @test e isa ArgumentError
        @test occursin("not concrete", e.msg)
        @test occursin("Any", e.msg)
    end

    # Test SortedDict with Vector{Any}
    # Using mixed types to illustrate realistic scenarios
    data_sorted_any = SortedDict{Dates.DateTime, Vector{Any}}(
        Dates.DateTime("2020-01-01") => Any[1.0, 2, 3.0],
        Dates.DateTime("2020-01-02") => Any[4, 5.0, 6],
    )
    @test_throws ArgumentError IS.transform_array_for_hdf(data_sorted_any)
    try
        IS.transform_array_for_hdf(data_sorted_any)
    catch e
        @test e isa ArgumentError
        @test occursin("not concrete", e.msg)
        @test occursin("SortedDict", e.msg)
    end

    # Test unsupported concrete type - should give informative error about no method
    struct TestUnsupportedType
        value::Int
    end
    data_unsupported = [TestUnsupportedType(1), TestUnsupportedType(2)]
    @test_throws ArgumentError IS.transform_array_for_hdf(data_unsupported)
    try
        IS.transform_array_for_hdf(data_unsupported)
    catch e
        @test e isa ArgumentError
        @test occursin("No transform_array_for_hdf method is defined", e.msg)
        @test occursin("TestUnsupportedType", e.msg)
    end
end
