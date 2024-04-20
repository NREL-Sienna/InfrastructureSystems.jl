
"""
Thrown upon detection of user data that is not supported.
"""
struct DataFormatError <: Exception
    msg::AbstractString
end

struct InvalidRange <: Exception
    msg::AbstractString
end

struct InvalidValue <: Exception
    msg::AbstractString
end

struct ConflictingInputsError <: Exception
    msg::AbstractString
end

struct HashMismatchError <: Exception
    msg::AbstractString
end

"""
Indicate that the feature at hand happens to not be implemented for the given data even
though it could be. If it is a category mistake to imagine this feature defined on that
data, use another exception, like `TypeError` or `ArgumentError`.
"""
struct UnimplementedError <: Exception
    msg::AbstractString
end

UnimplementedError(feature, data) =
    UnimplementedError("$feature not currently implemented for $data")

Base.showerror(io::IO, e::UnimplementedError) =
    println(io, "$UnimplementedError: $(e.msg)")

const CONSTANT = Float64
const LIM_TOL = 1e-6
const XY_COORDS = @NamedTuple{x::Float64, y::Float64}
