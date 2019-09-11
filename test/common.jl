
struct TestComponent <: Component
    name::AbstractString
    val::Int
    internal::InfrastructureSystemsInternal
end

function TestComponent(name, val, internal=InfrastructureSystemsInternal())
    return TestComponent(name, val, internal)
end

function create_system_data(; with_forecasts=false)
    data = SystemData{Component}()

    name = "Component1"
    component = TestComponent(name, 5)
    add_component!(data, component)

    if with_forecasts
        file = joinpath(FORECASTS_DIR, "ComponentsAsColumnsNoTime.json")
        add_forecasts!(data, file, IS)

        forecasts = get_all_forecasts(data)
        @assert length(forecasts) > 0
    end

    return data
end

function get_all_forecasts(data)
    return collect(iterate_forecasts(data))
end

