"""
Throw an `AssertionError` if `op(exp1, exp2)` is `false`.

# Examples
```
julia> a = 3; b = 4;
julia> @assert_op a == b
ERROR: AssertionError: 3 is not isequal 4

julia> @assert_op a + 3 == b + 4
ERROR: AssertionError: 6 is not == 8

julia> IS.@assert_op a isequal b
ERROR: AssertionError: 3 is not isequal 4
```
"""
macro assert_op(exp1, op, exp2)
    assert_op(exp1, op, exp2)
end

macro assert_op(expr...)
    assert_op(expr)
end

function assert_op(expr::Expr)
    @assert expr.head == :call
    @assert length(expr.args) == 3

    assert_op(expr.args[2], expr.args[1], expr.args[3])
end

function assert_op(expr::Tuple{Expr})
    @assert length(expr) == 1
    assert_op(expr[1])
end

function assert_op(exp1, op, exp2)
    return :(
        if !$op($(esc(exp1)), $(esc(exp2)))
            val1 = $(esc(exp1))
            val2 = $(esc(exp2))
            op_str = $(esc(op))
            throw(AssertionError("$val1 is not $op_str $val2"))
        end
    )
end
