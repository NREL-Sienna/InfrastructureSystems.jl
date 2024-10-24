"""
    Simulation
"""
module Simulation

import ..InfrastructureSystems
const IS = InfrastructureSystems

import ..InfrastructureSystems:
    @scoped_enum

include("enums.jl")

using DocStringExtensions

@template (FUNCTIONS, METHODS) = """
                                 $(TYPEDSIGNATURES)
                                 $(DOCSTRING)
                                 """

end
