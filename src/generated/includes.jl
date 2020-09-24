include("DeterministicMetadata.jl")
include("Deterministic.jl")
include("ProbabilisticMetadata.jl")
include("Probabilistic.jl")
include("ScenariosMetadata.jl")
include("Scenarios.jl")
include("SingleTimeSeriesMetadata.jl")
include("SingleTimeSeries.jl")

export get_count
export get_data
export get_horizon
export get_initial_time
export get_initial_time_stamp
export get_internal
export get_interval
export get_label
export get_length
export get_percentiles
export get_resolution
export get_scaling_factor_multiplier
export get_scenario_count
export get_time_series_uuid
export set_count!
export set_data!
export set_horizon!
export set_initial_time!
export set_initial_time_stamp!
export set_internal!
export set_interval!
export set_label!
export set_length!
export set_percentiles!
export set_resolution!
export set_scaling_factor_multiplier!
export set_scenario_count!
export set_time_series_uuid!
