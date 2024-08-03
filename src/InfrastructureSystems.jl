isdefined(Base, :__precompile__) && __precompile__()

module InfrastructureSystems

# Cost aliases don't display properly unless they are exported from IS
export LinearCurve, QuadraticCurve
export PiecewisePointCurve, PiecewiseIncrementalCurve, PiecewiseAverageCurve

import Base: @kwdef
import CSV
import DataFrames
import DataFrames: DataFrame
import Dates
import JSON3
import Logging
import Random
import Pkg
import PrettyTables
import SHA
import StructTypes
import TerminalLoggers: TerminalLogger, ProgressLevel
import TimeSeries
import TimerOutputs
import TOML
using DataStructures: OrderedDict, SortedDict
import SQLite
import Tables

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

  - get_uuid()

Subtypes may contain time series. Which requires

  - supports_time_series(::SupplementalAttribute)

All subtypes must include an instance of ComponentUUIDs in order to track
components attached to each attribute.
"""
abstract type SupplementalAttribute <: InfrastructureSystemsType end

get_name(value::InfrastructureSystemsComponent) = value.name
supports_supplemental_attributes(::InfrastructureSystemsComponent) = true
supports_time_series(::InfrastructureSystemsComponent) = false
supports_time_series(::SupplementalAttribute) = false

function set_name_internal!(value::InfrastructureSystemsComponent, name)
    value.name = name
    return
end

set_name!(value::InfrastructureSystemsComponent, name) = set_name_internal!(value)
get_internal(value::InfrastructureSystemsComponent) = value.internal

include("common.jl")
include("utils/timers.jl")
include("utils/assert_op.jl")
include("utils/recorder_events.jl")
include("utils/flatten_iterator_wrapper.jl")
include("utils/generate_struct_files.jl")
include("utils/generate_structs.jl")
include("utils/lazy_dict_from_iterator.jl")
include("utils/logging.jl")
include("utils/stdout_redirector.jl")
include("utils/sqlite.jl")
include("function_data.jl")
include("utils/utils.jl")
include("internal.jl")
include("time_series_storage.jl")
include("abstract_time_series.jl")
include("forecasts.jl")
include("static_time_series.jl")
include("time_series_parameters.jl")
include("containers.jl")
include("component_uuids.jl")
include("geographic_supplemental_attribute.jl")
include("generated/includes.jl")
include("time_series_parser.jl")
include("single_time_series.jl")
include("deterministic_single_time_series.jl")
include("deterministic.jl")
include("probabilistic.jl")
include("scenarios.jl")
include("deterministic_metadata.jl")
include("hdf5_time_series_storage.jl")
include("in_memory_time_series_storage.jl")
include("time_series_structs.jl")
include("time_series_formats.jl")
include("time_series_metadata_store.jl")
include("time_series_manager.jl")
include("time_series_interface.jl")
include("time_series_cache.jl")
include("time_series_utils.jl")
include("supplemental_attribute_associations.jl")
include("supplemental_attribute_manager.jl")
include("components.jl")
include("iterators.jl")
include("component.jl")
include("results.jl")
include("serialization.jl")
include("system_data.jl")
include("subsystems.jl")
include("validation.jl")
include("utils/print.jl")
include("utils/test.jl")
include("units.jl")
include("value_curve.jl")
include("cost_aliases.jl")
include("production_variable_cost_curve.jl")
include("deprecated.jl")
include("Optimization/Optimization.jl")
include("Simulation/Simulation.jl")
end # module
