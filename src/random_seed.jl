function get_random_seed()
    if haskey(ENV, "SIENNA_RANDOM_SEED")
        try
            return parse(Int, ENV["SIENNA_RANDOM_SEED"])
        catch e
            val = ENV["SIENNA_RANDOM_SEED"]
            @error("SIENNA_RANDOM_SEED: $val can't be read as an integer value")
            rethrow()
        end
        return SIENNA_RANDOM_SEED
    else
        return rand(Int)
    end
end
