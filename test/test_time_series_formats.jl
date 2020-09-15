
import CSV
import TimeSeries

@testset "Test TimeSeries formats" begin
    formats = [
        (
            IS.TimeSeriesFormatYMDPeriodAsColumn,
            joinpath(FORECASTS_DIR, "YMDPeriodAsColumn.csv"),
            nothing,
        ),
        (
            IS.TimeSeriesFormatYMDPeriodAsHeader,
            joinpath(FORECASTS_DIR, "YMDPeriodAsHeader.csv"),
            "fake",
        ),
        (
            IS.TimeSeriesFormatComponentsAsColumnsNoTime,
            joinpath(FORECASTS_DIR, "ComponentsAsColumnsNoTime.csv"),
            nothing,
        ),
        (
            IS.TimeSeriesFormatDateTimeAsColumn,
            joinpath(FORECASTS_DIR, "DateTimeAsColumn.csv"),
            nothing,
        ),
        (
            IS.TimeSeriesFormatDateTimePeriodAsColumn,
            joinpath(FORECASTS_DIR, "DateTimePeriodAsColumn.csv"),
            nothing,
        ),
    ]

    for (format, filename, component_name) in formats
        file = CSV.File(filename)
        @test format == IS.get_time_series_format(file)

        data = IS.read_time_series(filename, component_name)
        @test data isa TimeSeries.TimeArray
    end
end
