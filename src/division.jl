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