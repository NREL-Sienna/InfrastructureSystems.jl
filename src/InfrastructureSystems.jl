isdefined(Base, :__precompile__) && __precompile__()

module InfrastructureSystems

import CSV
import DataFrames
import Dates
import JSON3
import PrettyTables
import TimeSeries
using DataStructures: SortedDict

using DocStringExtensions

@template (FUNCTIONS, METHODS) = """
                                 $(TYPEDSIGNATURES)
                                 $(DOCSTRING)
                                 """

# IS should not export any function since it can have name clashes with other packages.
# Do not add export statements.

"""
Base type for any struct in the SIIP packages.
All structs must implement a kwarg-only constructor to allow deserializing from a Dict.
"""
abstract type InfrastructureSystemsType end

"""
Base type for structs that are stored in a system.

Required interface functions for subtypes:
- get_name()
- get_internal()

Optional interface functions:
- get_time_series_container()

Subtypes may contain time series.
"""
abstract type InfrastructureSystemsComponent <: InfrastructureSystemsType end

"""
Base type for auxillary structs. These should not be stored in a system.
"""
abstract type DeviceParameter <: InfrastructureSystemsType end

"""
Return the internal time_series storage container or nothing, if the type doesn't store
time series.

Subtypes need to implement this method if they store time series.
"""
function get_time_series_container(value::InfrastructureSystemsComponent)
    return nothing
end

set_time_series_container!(value::InfrastructureSystemsComponent) = nothing

get_name(value::InfrastructureSystemsComponent) = value.name
set_name!(value::InfrastructureSystemsComponent, name) = value.name = name
get_internal(value::InfrastructureSystemsComponent) = value.internal

include("common.jl")
include("internal.jl")
include("utils/recorder_events.jl")
include("utils/flatten_iterator_wrapper.jl")
include("utils/generate_structs.jl")
include("utils/lazy_dict_from_iterator.jl")
include("utils/logging.jl")
include("utils/stdout_redirector.jl")
include("utils/utils.jl")
include("time_series_storage.jl")
include("abstract_time_series.jl")
include("forecasts.jl")
include("static_time_series.jl")
include("time_series_container.jl")
include("time_series_parser.jl")
include("components.jl")
include("generated/includes.jl")
include("hdf5_time_series_storage.jl")
include("in_memory_time_series_storage.jl")
include("time_series_formats.jl")
include("component.jl")
include("single_time_series.jl")
include("time_series_parameters.jl")
include("time_series_utils.jl")
include("deterministic.jl")
include("probabilistic.jl")
include("results.jl")
include("serialization.jl")
include("system_data.jl")
include("validation.jl")
include("utils/print.jl")
include("utils/test.jl")
include("units.jl")

end # module
