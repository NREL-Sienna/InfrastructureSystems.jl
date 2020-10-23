
import CSV
import TimeSeries

@testset "Test TimeSeries formats" begin
    formats = [
        (
            IS.SingleTimeSeries,
            IS.TimeSeriesFormatYMDPeriodAsColumn,
            joinpath(FORECASTS_DIR, "YMDPeriodAsColumn.csv"),
            nothing,
        ),
        (
            IS.SingleTimeSeries,
            IS.TimeSeriesFormatYMDPeriodAsHeader,
            joinpath(FORECASTS_DIR, "YMDPeriodAsHeader.csv"),
            "fake",
        ),
        (
            IS.SingleTimeSeries,
            IS.TimeSeriesFormatComponentsAsColumnsNoTime,
            joinpath(FORECASTS_DIR, "ComponentsAsColumnsNoTime.csv"),
            nothing,
        ),
        (
            IS.SingleTimeSeries,
            IS.TimeSeriesFormatDateTimeAsColumn,
            joinpath(FORECASTS_DIR, "DateTimeAsColumn.csv"),
            nothing,
        ),
        (
            IS.SingleTimeSeries,
            IS.TimeSeriesFormatDateTimePeriodAsColumn,
            joinpath(FORECASTS_DIR, "DateTimePeriodAsColumn.csv"),
            nothing,
        ),
        (
            IS.SingleTimeSeries,
            IS.TimeSeriesFormatDateTimeAsColumn,
            joinpath(FORECASTS_DIR, "DateTimeAsColumnDeterministic.csv"),
            nothing,
        ),
    ]

    for (time_series_type, format, filename, component_name) in formats
        file = CSV.File(filename)
        @test format == IS.get_time_series_format(file)

        data = IS.read_time_series(time_series_type, filename, component_name)
        @test data isa IS.RawTimeSeries
    end
end
