"""
    Simulation
"""
module Simulation

import ..InfrastructureSystems as IS

import ..InfrastructureSystems:
    @scoped_enum

include("enums.jl")

using DocStringExtensions

@template (FUNCTIONS, METHODS) = """
                                 $(TYPEDSIGNATURES)
                                 $(DOCSTRING)
                                 """

end
