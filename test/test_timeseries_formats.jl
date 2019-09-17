
import CSV
import TimeSeries


@testset "Test Timeseries formats" begin
    formats = [
        (IS.TimeseriesFormatYMDPeriodAsColumn,
         joinpath(FORECASTS_DIR, "YMDPeriodAsColumn.csv"),
         nothing,
        ),
        (IS.TimeseriesFormatYMDPeriodAsHeader,
         joinpath(FORECASTS_DIR, "YMDPeriodAsHeader.csv"),
         "fake",
        ),
        (IS.TimeseriesFormatComponentsAsColumnsNoTime,
         joinpath(FORECASTS_DIR, "ComponentsAsColumnsNoTime.csv"),
         nothing),
        # TODO: add a file that has a column name with a DateTime.
        # TODO: add a file that more than one unique timestamp so that we can fully test
        # IS.get_step_time().
    ]

    for (format, filename, component_name) in formats
        file = CSV.File(filename)
        @test format == IS.get_timeseries_format(file)

        data = IS.read_timeseries(filename, component_name)
        @test data isa TimeSeries.TimeArray
    end
end
