module InfrastructureSystems

import CSV
import DataFrames
import Dates
import JSON
import JSON2
import TimeSeries

export Components
export FlattenIteratorWrapper
export Forecasts
export InfrastructureSystemsInternal
export InfrastructureSystemsType
export SystemData
export TimeseriesFileMetadata

export Forecast
export Deterministic
export Probabilistic
export ScenarioBased

export get_limits
export get_name
export open_file_logger
export validate_struct

# Components functions
export iterate_components
export add_component!
export remove_components!
export remove_component!
export get_component
export get_components_by_name
export get_components

# Forecasts functions
export add_forecasts!
export add_forecast!
export remove_forecast!
export clear_forecasts!
export get_forecast_initial_times
export get_forecasts
export get_forecasts_horizon
export get_forecasts_initial_time
export get_forecasts_interval
export get_forecasts_resolution
export get_forecast_component_name
export get_forecast_value
export get_timeseries
export iterate_forecasts
export make_forecasts
export split_forecasts!
export read_timeseries_metadata

export runtests

export DataFormatError
export InvalidRange
export InvalidValue

# Every subtype must implement InfrastructureSystems.get_name() or have a field called name.
abstract type InfrastructureSystemsType end

get_name(value::InfrastructureSystemsType) = value.name


include("common.jl")
include("internal.jl")
include("utils/flatten_iterator_wrapper.jl")
include("utils/generate_structs.jl")
include("utils/lazy_dict_from_iterator.jl")
include("utils/logging.jl")
include("utils/test.jl")
include("utils/utils.jl")

include("components.jl")
include("forecasts.jl")
include("generated/includes.jl")
include("deterministic_forecast.jl")
include("supplemental_constructors.jl")
include("supplemental_accessors.jl")
include("forecast_parser.jl")
include("timeseries_formats.jl")
include("serialization.jl")
include("system_data.jl")
include("validation.jl")

end # module
