time_period_conversion(time_period::Dates.TimePeriod) = convert(Dates.Millisecond, time_period)
time_period_conversion(time_period::Dates.DatePeriod) = convert(Dates.Millisecond, time_period)
