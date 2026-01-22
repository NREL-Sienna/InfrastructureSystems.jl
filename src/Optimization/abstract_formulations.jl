abstract type AbstractDeviceFormulation end

"""
Base abstract type for all power model formulations.
Intermediate types (AbstractActivePowerModel, AbstractDCPModel, etc.) are
defined in PowerModelsExt for PowerModels-specific functionality.
"""
abstract type AbstractPowerModel end

abstract type AbstractHVDCNetworkModel end
