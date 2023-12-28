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
    Channel() do channel
        for m_dict in values(container.data)
            for member in values(m_dict)
                put!(channel, member)
            end
        end
    end
end

function iterate_container_with_time_series(container::InfrastructureSystemsContainer)
    Channel() do channel
        for m_dict in values(container.data)
            for member in values(m_dict)
                if has_time_series(member)
                    put!(channel, member)
                end
            end
        end
    end
end

function get_num_members(container::InfrastructureSystemsContainer)
    count = 0
    for members in values(container.data)
        count += length(members)
    end
    return count
end

function clear_time_series!(container::InfrastructureSystemsContainer)
    for member in iterate_components_with_time_series(container)
        clear_time_series!(member)
    end
    return
end
