isdefined(Base, :__precompile__) && __precompile__()

module InfrastructureSystems

import CSV
import DataFrames
import Dates
import JSON3
import Logging
import Random
import Pkg
import PrettyTables
import StructTypes
import TerminalLoggers: TerminalLogger, ProgressLevel
import TimeSeries
import TOML
using DataStructures: OrderedDict, SortedDict

using DocStringExtensions

@template (FUNCTIONS, METHODS) = """
                                 $(TYPEDSIGNATURES)
                                 $(DOCSTRING)
                                 """

# IS should not export any function since it can have name clashes with other packages.
# Do not add export statements.

"""
Base type for any struct in the Sienna packages.
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
  - get_supplemental_attributes_container()

Subtypes may contain time series.
"""
abstract type InfrastructureSystemsComponent <: InfrastructureSystemsType end

"""
Base type for auxillary structs. These should not be stored in a system.
"""
abstract type DeviceParameter <: InfrastructureSystemsType end

"""
Base type for structs that store supplemental attributes

Required interface functions for subtypes:

  - get_internal()

Optional interface functions:

  - get_time_series_container()
  - get_component_uuids()
    Required if the struct does not include the field component_uuids.
  - get_uuid()

Subtypes may contain time series. Which requires

  - get_time_series_container()

All subtypes must include an instance of ComponentUUIDs in order to track
components attached to each attribute.
"""
abstract type SupplementalAttribute <: InfrastructureSystemsType end

"""
Return the internal time_series storage container or nothing, if the type doesn't store
time series.

Subtypes need to implement this method if they store time series.
"""
function get_time_series_container(value::InfrastructureSystemsComponent)
    return nothing
end

set_time_series_container!(value::InfrastructureSystemsComponent, _) = nothing

get_name(value::InfrastructureSystemsComponent) = value.name

function set_name_internal!(value::InfrastructureSystemsComponent, name)
    value.name = name
    return
end

set_name!(value::InfrastructureSystemsComponent, name) = set_name_internal!(value)
get_internal(value::InfrastructureSystemsComponent) = value.internal

include("common.jl")
include("utils/assert_op.jl")
include("utils/recorder_events.jl")
include("utils/flatten_iterator_wrapper.jl")
include("utils/generate_struct_files.jl")
include("utils/generate_structs.jl")
include("utils/lazy_dict_from_iterator.jl")
include("utils/logging.jl")
include("utils/stdout_redirector.jl")
include("function_data.jl")
include("utils/utils.jl")
include("internal.jl")
include("time_series_storage.jl")
include("abstract_time_series.jl")
include("forecasts.jl")
include("static_time_series.jl")
include("time_series_container.jl")
include("time_series_parser.jl")
include("containers.jl")
include("component_uuids.jl")
include("supplemental_attribute.jl")
include("supplemental_attributes_container.jl")
include("supplemental_attributes.jl")
include("components.jl")
include("iterators.jl")
include("geographic_supplemental_attribute.jl")
include("generated/includes.jl")
include("single_time_series.jl")
include("deterministic_single_time_series.jl")
include("deterministic.jl")
include("probabilistic.jl")
include("scenarios.jl")
include("deterministic_metadata.jl")
include("hdf5_time_series_storage.jl")
include("in_memory_time_series_storage.jl")
include("time_series_formats.jl")
include("time_series_cache.jl")
include("time_series_parameters.jl")
include("time_series_utils.jl")
include("optimization_container_types.jl")
include("optimization_container_keys.jl")
include("optimization_container_metadata.jl")
include("model_store_params.jl")
include("model_internal.jl")
include("component.jl")
include("results.jl")
include("serialization.jl")
include("system_data.jl")
include("subsystems.jl")
include("time_series_interface.jl")
include("validation.jl")
include("utils/print.jl")
include("utils/test.jl")
include("units.jl")
include("deprecated.jl")

end # module
