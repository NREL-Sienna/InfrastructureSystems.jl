
struct TestComponent <: InfrastructureSystemsType
    name::AbstractString
    val::Int
    internal::InfrastructureSystemsInternal
end

function TestComponent(name, val)
    return TestComponent(name, val, InfrastructureSystemsInternal())
end

function JSON2.read(io::IO, ::Type{TestComponent})
    data = JSON2.read(io)
    return TestComponent(data.name, data.val, JSON2.read(JSON2.write(data.internal),
                                                         InfrastructureSystemsInternal))
end

function runtests(args...)
    test_prefix = "test_"
    for arg in args
        if !startswith(arg, test_prefix)
            arg = test_prefix * arg
        end
        push!(ARGS, arg)
    end

    try
        include("test/runtests.jl")
    finally
        empty!(ARGS)
    end
end
