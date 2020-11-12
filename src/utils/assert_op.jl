"""
Throw an `AssertionError` if conditions like `op(exp1, exp2)` are `false`, where `op` is a conditional infix operator.

# Examples

```
julia> a = 3; b = 4;
julia> @assert_op a == b
ERROR: AssertionError: 3 == 4

julia> @assert_op a + 3 > b + 4
ERROR: AssertionError: 6 > 8
```
"""
macro assert_op(expr)
    assert_op(expr)
end

function assert_op(expr::Expr)
    # Only special case expressions of the form `expr1 == expr2`
    if length(expr.args) == 3 && expr.head == :call
        return assert_op(expr.args[1], expr.args[2], expr.args[3])
    else
        return :(@assert $(expr))
    end
end

function assert_op(op, exp1, exp2)
    return :(
        if !$op($(esc(exp1)), $(esc(exp2)))
            val1 = $(esc(exp1))
            val2 = $(esc(exp2))
            op_str = $(esc(op))
            throw(AssertionError("$val1 $op_str $val2"))
        end
    )
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
