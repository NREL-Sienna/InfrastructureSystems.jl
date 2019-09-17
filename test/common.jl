
struct TestComponent <: IS.InfrastructureSystemsType
    name::AbstractString
    val::Int
    internal::IS.InfrastructureSystemsInternal
end

function TestComponent(name, val, internal=IS.InfrastructureSystemsInternal())
    return TestComponent(name, val, internal)
end

function create_system_data(; with_forecasts=false)
    data = IS.SystemData()

    name = "Component1"
    component = TestComponent(name, 5)
    IS.add_component!(data, component)

    if with_forecasts
        file = joinpath(FORECASTS_DIR, "ComponentsAsColumnsNoTime.json")
        IS.add_forecasts!(data, IS.make_forecasts(data, file, IS))

        forecasts = get_all_forecasts(data)
        @assert length(forecasts) > 0
    end

    return data
end

function get_all_forecasts(data)
    return collect(IS.iterate_forecasts(data))
end
