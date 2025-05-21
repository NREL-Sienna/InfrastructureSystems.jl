
# This files contains components that can be used for tests.
# Serialization/de-serialization will not work in all cases because of how the type names
# show up in different environments.
# InfrastructureSystemsTests.Generator vs Main.InfrastructureSystemsTests.Generator

abstract type AbstractPowerSystemComponent <: IS.InfrastructureSystemsComponent end
abstract type AbstractGenerator <: AbstractPowerSystemComponent end
abstract type AbstractRenewableGenerator <: AbstractGenerator end

IS.get_available(component::AbstractPowerSystemComponent) = component.available

struct Bus <: AbstractPowerSystemComponent
    name::String
    available::Bool
    internal::IS.InfrastructureSystemsInternal
end

function Bus(name, available)
    Bus(name, available, IS.InfrastructureSystemsInternal())
end

struct ThermalGenerator <: AbstractGenerator
    name::String
    bus::Bus
    available::Bool
    internal::IS.InfrastructureSystemsInternal
end

function ThermalGenerator(name, bus, available)
    ThermalGenerator(name, bus, available, IS.InfrastructureSystemsInternal())
end

struct PVGenerator <: AbstractRenewableGenerator
    name::String
    bus::Bus
    available::Bool
    internal::IS.InfrastructureSystemsInternal
end

function PVGenerator(name, bus, available)
    PVGenerator(name, bus, available, IS.InfrastructureSystemsInternal())
end
