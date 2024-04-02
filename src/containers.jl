abstract type InfrastructureSystemsContainer end

get_display_string(x::InfrastructureSystemsContainer) = string(nameof(typeof(x)))

function serialize(container::InfrastructureSystemsContainer)
    # time_series_storage and validation_descriptors are serialized elsewhere.
    return [serialize(x) for y in values(container.data) for x in values(y)]
end

"""
Iterates over all data in the container.
"""
function iterate_container(container::InfrastructureSystemsContainer)
    return (y for x in values(container.data) for y in values(x))
end

function get_num_members(container::InfrastructureSystemsContainer)
    return mapreduce(length, +, values(container.data); init = 0)
end
