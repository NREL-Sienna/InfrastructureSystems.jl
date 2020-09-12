include("DeterministicMetadata.jl")
include("Deterministic.jl")
include("ProbabilisticMetadata.jl")
include("Probabilistic.jl")
include("ScenarioBasedMetadata.jl")
include("ScenarioBased.jl")
include("PiecewiseFunction.jl")
include("PiecewiseFunctionMetadata.jl")

export get_break_points
export get_data
export get_horizon
export get_initial_time
export get_internal
export get_label
export get_percentiles
export get_resolution
export get_scaling_factor_multiplier
export get_scenario_count
export get_time_series_uuid
export set_break_points!
export set_data!
export set_horizon!
export set_initial_time!
export set_internal!
export set_label!
export set_percentiles!
export set_resolution!
export set_scaling_factor_multiplier!
export set_scenario_count!
export set_time_series_uuid!
