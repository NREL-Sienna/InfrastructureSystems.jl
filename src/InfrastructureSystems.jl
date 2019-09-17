module InfrastructureSystems

import CSV
import DataFrames
import Dates
import JSON
import JSON2
import TimeSeries

# IS should not export any function since it can have name clashes with other packages.
# Do not add export statements.

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
include("utils/print.jl")

end # module
