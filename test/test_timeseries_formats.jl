
import CSV
import TimeSeries

@testset "Test Timeseries formats" begin
    formats = [
        (
            IS.TimeseriesFormatYMDPeriodAsColumn,
            joinpath(FORECASTS_DIR, "YMDPeriodAsColumn.csv"),
            nothing,
        ),
        (
            IS.TimeseriesFormatYMDPeriodAsHeader,
            joinpath(FORECASTS_DIR, "YMDPeriodAsHeader.csv"),
            "fake",
        ),
        (
            IS.TimeseriesFormatComponentsAsColumnsNoTime,
            joinpath(FORECASTS_DIR, "ComponentsAsColumnsNoTime.csv"),
            nothing,
        ),
        (
            IS.TimeseriesFormatDateTimePeriodAsColumn,
            joinpath(FORECASTS_DIR, "DateTimeAsColumn.csv"),
            nothing,
        ),
    ]

    for (format, filename, component_name) in formats
        file = CSV.File(filename)
        @test format == IS.get_timeseries_format(file)

        data = IS.read_time_series(filename, component_name)
        @test data isa TimeSeries.TimeArray
    end
end
