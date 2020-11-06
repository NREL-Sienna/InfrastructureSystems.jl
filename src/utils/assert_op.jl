"""
Throw an `AssertionError` if `op(exp1, exp2)` is `false`.

Use only the forms below. `@assert_op a == b` is not currently supported.

# Examples
```
julia> a = 3; b = 4;
julia> @assert_op(a, ==, b)
ERROR: AssertionError: a = 3, b = 4

julia> IS.@assert_op(a + 3, ==, b + 4)
ERROR: AssertionError: a + 3 = 6, b + 4 = 8

julia> IS.@assert_op a isequal b
ERROR: AssertionError: a = 3, b = 4
```
"""
macro assert_op(exp1, op, exp2)
    return :(
        if $op($(esc(exp1)), $(esc(exp2)))
            return nothing
        else
            name1 = $(string(exp1))
            name2 = $(string(exp2))
            val1 = $(esc(exp1))
            val2 = $(esc(exp2))
            throw(AssertionError("$name1 = $val1, $name2 = $val2"))
        end
    )
end
