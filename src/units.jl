time_period_conversion(time_period::Union{Dates.TimePeriod, Dates.DatePeriod}) = convert(Dates.Millisecond, time_period)
