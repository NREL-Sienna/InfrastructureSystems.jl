
abstract type BaseComponent <: InfrastructureSystemType end

struct Component <: BaseComponent
    name::AbstractString
    val::Int
end
