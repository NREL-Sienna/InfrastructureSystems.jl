module InfrastructureSystems

import DataFrames

export InvalidParameter

export InfrastructureSystemType
export Components
export FlattenIteratorWrapper

export open_file_logger
export iterate_components
export add_component!
export remove_components!
export remove_component!
export get_component
export get_components_by_name
export get_components
export get_name

# Every subtype must implement get_name().
# TODO: how to document interface formally?
abstract type InfrastructureSystemType end
# TODO: not correct, just a placeholder
get_name(value::InfrastructureSystemType) = value.name

include("common.jl")
include("internal.jl")
include("utils/flatten_iterator_wrapper.jl")
include("utils/logging.jl")
include("utils/utils.jl")

include("components.jl")


end # module
