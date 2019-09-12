
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
