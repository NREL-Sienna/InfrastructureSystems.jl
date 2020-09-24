abstract type Forecast <: TimeSeriesData end

get_label(value::Forecast) = value.label
get_percentiles(value::Forecast) = value.percentiles
get_data(value::Forecast) = value.data
get_scaling_factor_multiplier(value::Forecast) = value.scaling_factor_multiplier
