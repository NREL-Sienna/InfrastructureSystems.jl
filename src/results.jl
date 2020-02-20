"""To implement a sub-type of this you need to implement the methods below."""
abstract type Results end
function get_variables(r::T) where T <: Results
    error("get_variables must be implemented for $T")
end

function get_total_cost(r::T) where T <: Results
    error("get_total_cost must be implemented for $T")
end

function get_optimizer_log(r::T) where T <: Results
    error("get_optimizer_log must be implemented for $T")
end

function get_time_stamp(r::T) where T <: Results
    error("get_time_stamp must be implemented for $T")
end

function write_results(r::T) where T <: Results
    error("write_results must be implemented for $T")
end