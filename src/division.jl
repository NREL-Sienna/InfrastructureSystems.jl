function /(num::Dates.Hour, denom::Dates.Minute)
    numerator = convert(Dates.Minute, num)
    denominator = convert(Dates.Minute, denom)
    division = numerator / denominator
    return division
end

function /(num::Dates.Minute, denom::Dates.Hour)
    numerator = convert(Dates.Minute, num)
    denominator = convert(Dates.Minute, denom)
    division = numerator / denominator
    return division
end

function /(num::Dates.Millisecond, denom::Dates.Hour)
    numerator = convert(Dates.Minute, num)
    denominator = convert(Dates.Minute, denom)
    division = numerator / denominator
    return division
end

function /(num::Dates.Hour, denom::Dates.Millisecond)
    numerator = convert(Dates.Minute, num)
    denominator = convert(Dates.Minute, denom)
    division = numerator / denominator
    return division
end

function /(num::Dates.Millisecond, denom::Dates.Minute)
    numerator = convert(Dates.Minute, num)
    denominator = convert(Dates.Minute, denom)
    division = numerator / denominator
    return division
end

function /(num::Dates.Minute, denom::Dates.Millisecond)
    numerator = convert(Dates.Minute, num)
    denominator = convert(Dates.Minute, denom)
    division = numerator / denominator
    return division
end

function div(num::Dates.Hour, denom::Dates.Minute)
    numerator = convert(Dates.Minute, num)
    denominator = convert(Dates.Minute, denom)
    division = numerator / denominator
    return division
end

function div(num::Dates.Minute, denom::Dates.Hour)
    numerator = convert(Dates.Minute, num)
    denominator = convert(Dates.Minute, denom)
    division = numerator / denominator
    return division
end

function div(num::Dates.Millisecond, denom::Dates.Hour)
    numerator = convert(Dates.Minute, num)
    denominator = convert(Dates.Minute, denom)
    division = numerator / denominator
    return division
end

function div(num::Dates.Hour, denom::Dates.Millisecond)
    numerator = convert(Dates.Minute, num)
    denominator = convert(Dates.Minute, denom)
    division = numerator / denominator
    return division
end

function div(num::Dates.Millisecond, denom::Dates.Minute)
    numerator = convert(Dates.Minute, num)
    denominator = convert(Dates.Minute, denom)
    division = numerator / denominator
    return division
end

function div(num::Dates.Minute, denom::Dates.Millisecond)
    numerator = convert(Dates.Minute, num)
    denominator = convert(Dates.Minute, denom)
    division = numerator / denominator
    return division
end

function +(num::Dates.Hour, denom::Dates.Minute)
    numerator1 = convert(Dates.Millisecond, num)
    numerator2 = convert(Dates.Millisecond, denom)
    addition = numerator1 + numerator2
    return addition
end

function +(num::Dates.Minute, denom::Dates.Hour)
    numerator1 = convert(Dates.Millisecond, num)
    numerator2 = convert(Dates.Millisecond, denom)
    addition = numerator1 + numerator2
    return addition
end

function +(num::Dates.Millisecond, denom::Dates.Hour)
    numerator1 = convert(Dates.Millisecond, num)
    numerator2 = convert(Dates.Millisecond, denom)
    addition = numerator1 + numerator2
    return addition
end

function +(num::Dates.Hour, denom::Dates.Millisecond)
    numerator1 = convert(Dates.Millisecond, num)
    numerator2 = convert(Dates.Millisecond, denom)
    addition = numerator1 + numerator2
    return addition
end

function +(num::Dates.Millisecond, denom::Dates.Minute)
    numerator1 = convert(Dates.Millisecond, num)
    numerator2 = convert(Dates.Millisecond, denom)
    addition = numerator1 + numerator2
    return addition
end

function +(num::Dates.Minute, denom::Dates.Millisecond)
    numerator1 = convert(Dates.Millisecond, num)
    numerator2 = convert(Dates.Millisecond, denom)
    addition = numerator1 + numerator2
    return addition
end