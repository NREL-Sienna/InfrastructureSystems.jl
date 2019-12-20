time_period_conversion(time_period::Union{Dates.TimePeriod, Dates.DatePeriod}) = convert(Dates.Millisecond, time_period)
time_period_conversion(time_periods::Dict) = convert(Dict{String, Dates.Millisecond}, time_periods)
