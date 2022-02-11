"""
To implement a sub-type of this you need to implement the methods below.
"""
abstract type Results end
function get_base_power(r::T) where {T <: Results}
    error("get_base_power must be implemented for $T")
end

function get_variables(r::T) where {T <: Results}
    error("get_variables must be implemented for $T")
end

function get_parameters(r::T) where {T <: Results}
    error("get_parameters must be implemented for $T")
end

function get_total_cost(r::T) where {T <: Results}
    error("get_total_cost must be implemented for $T")
end

function get_optimizer_stats(r::T) where {T <: Results}
    error("get_optimizer_stats must be implemented for $T")
end

function get_timestamp(r::T) where {T <: Results}
    error("get_timestamp must be implemented for $T")
end

function write_results(r::T) where {T <: Results}
    error("write_results must be implemented for $T")
end
