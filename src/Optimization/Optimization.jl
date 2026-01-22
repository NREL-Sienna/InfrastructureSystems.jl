"""
    Optimization

Base types and enums for optimization models. Concrete implementations
are provided by InfrastructureOptimizationModels.jl.
"""
module Optimization

import ..InfrastructureSystems as IS
import ..InfrastructureSystems: @scoped_enum

using DocStringExtensions

@template (FUNCTIONS, METHODS) = """
                                    $(TYPEDSIGNATURES)
                                    $(DOCSTRING)
                                    """

# Export enums
export ModelBuildStatus

# Export base abstract types
export AbstractOptimizationContainer
export OptimizationKeyType
export AbstractModelStoreParams

include("enums.jl")
include("optimization_container_types.jl")
include("abstract_model_store_params.jl")

end
