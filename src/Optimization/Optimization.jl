"""
    Optimization
"""
module Optimization

import Logging
import Serialization
import Dates

import CSV
import DataFrames

import ..InfrastructureSystems
const IS = InfrastructureSystems

import ..InfrastructureSystems:
    @scoped_enum,
    InfrastructureSystemsType,
    InfrastructureSystemsComponent,
    Results,
    TimeSeriesCacheKey,
    TimeSeriesCache,
    configure_logging,
    strip_module_name,
    to_namedtuple,
    get_uuid,
    compute_file_hash,
    convert_for_path,
    InvalidValue,
    COMPONENT_NAME_DELIMETER

using DocStringExtensions

@template (FUNCTIONS, METHODS) = """
                                    $(TYPEDSIGNATURES)
                                    $(DOCSTRING)
                                    """

export OptimizationProblemResults
export OptimizationProblemResultsExport
export OptimizerStats

include("enums.jl")
include("optimization_container_types.jl")
include("optimization_container_keys.jl")
include("abstract_model_store.jl")
include("abstract_model_store_params.jl")
include("model_internal.jl")
include("optimization_container_metadata.jl")
include("optimizer_stats.jl")
include("optimization_problem_results_export.jl")
include("optimization_problem_results.jl")
include("optimization_test_utils.jl")

end
