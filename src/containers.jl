abstract type InfrastructureSystemsContainer <: InfrastructureSystemsType end

get_display_string(x::InfrastructureSystemsContainer) = string(nameof(typeof(x)))

"""
Iterates over all data in the container.
"""
function iterate_container(container::InfrastructureSystemsContainer)
    return (y for x in values(container.data) for y in values(x))
end

function get_num_members(container::InfrastructureSystemsContainer)
    return mapreduce(length, +, values(container.data); init = 0)
end
