
import InfrastructureSystems

function main(args)
    if length(args) != 2
        println("Usage: julia generate_structs.jl INPUT_FILE OUTPUT_DIRECTORY")
        exit(1)
    end

    InfrastructureSystems.generate_structs(args[1], args[2])
end

main(ARGS)
