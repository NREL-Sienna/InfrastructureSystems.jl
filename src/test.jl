
function runtests(args...)
    test_prefix = "test_"
    for arg in args
        if !startswith(arg, test_prefix)
            arg = test_prefix * arg
        end
        push!(ARGS, arg)
    end

    include("test/runtests.jl")
    empty!(ARGS)
end
