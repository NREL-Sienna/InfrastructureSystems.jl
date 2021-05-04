# 1.4.2 Deprecations

function _add_component_kwarg_deprecation(kwargs)
    if haskey(kwargs, :deserialization_in_progress)
        Base.depwarn("Keyword deserialization_in_progress is deprecated, use allow_existing_time_series instead.", :add_component!)
        kw = Dict(k => v for (k, v) in kwargs if k != :deserialization_in_progress)
        kw[:allow_existing_time_series] = kwargs[:deserialization_in_progress]
        return kw
    else
        return kwargs
    end
end
