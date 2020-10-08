# NOTE: All constructors must be duplicated in src/deterministic.jl.

function DeterministicStandard(
    name::AbstractString,
    input_data::AbstractDict{Dates.DateTime, Vector{Float64}},
    resolution::Dates.Period;
    normalization_factor::NormalizationFactor = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
)
    if !isa(input_data, SortedDict)
        input_data = SortedDict(input_data...)
    end
    data = handle_normalization_factor(input_data, normalization_factor)
    return DeterministicStandard(name, resolution, data, scaling_factor_multiplier)
end

function DeterministicStandard(
    name::AbstractString,
    input_data::AbstractDict{Dates.DateTime, <:TimeSeries.TimeArray};
    normalization_factor::NormalizationFactor = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
)
    data = SortedDict{Dates.DateTime, Vector{Float64}}()
    resolution =
        TimeSeries.timestamp(first(values(input_data)))[2] -
        TimeSeries.timestamp(first(values(input_data)))[1]
    for (k, v) in input_data
        if length(size(v)) > 1
            throw(ArgumentError("TimeArray with timestamp $k has more than one column)"))
        end
        data[k] = TimeSeries.values(v)
    end

    return DeterministicStandard(
        name,
        data,
        resolution;
        normalization_factor = normalization_factor,
        scaling_factor_multiplier = scaling_factor_multiplier,
    )
end

function DeterministicStandard(
    name::AbstractString,
    input_data::AbstractDict{Dates.DateTime, <:Any},
    resolution::Dates.Period;
    normalization_factor::NormalizationFactor = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
)
    data = SortedDict{Dates.DateTime, Vector{Float64}}()
    for (k, v) in input_data
        try
            data[k] = Float64[i for i in v]
        catch e
            @error("The forecast data provided $(second(eltype(input_data))) can't be converted to Vector{Float64}")
            rethrow()
        end
    end
    @assert !isempty(data)

    return DeterministicStandard(
        name,
        data,
        resolution;
        normalization_factor = normalization_factor,
        scaling_factor_multiplier = scaling_factor_multiplier,
    )
end

function DeterministicStandard(
    name::AbstractString,
    series_data::RawTimeSeries,
    resolution::Dates.Period;
    normalization_factor::NormalizationFactor = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
)
    return DeterministicStandard(
        name,
        series_data.data,
        resolution;
        normalization_factor = normalization_factor,
        scaling_factor_multiplier = scaling_factor_multiplier,
    )
end

function DeterministicStandard(
    name::AbstractString,
    filename::AbstractString,
    component::InfrastructureSystemsComponent,
    resolution::Dates.Period;
    normalization_factor::NormalizationFactor = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
)
    component_name = get_name(component)
    raw_data = read_time_series(Deterministic, filename, component_name)
    return DeterministicStandard(
        name,
        raw_data,
        resolution;
        normalization_factor = normalization_factor,
        scaling_factor_multiplier = scaling_factor_multiplier,
    )
end

function get_array_for_hdf(forecast::DeterministicStandard)
    return hcat(values(forecast.data)...)
end

function get_horizon(forecast::DeterministicStandard)
    return length(first(values(get_data(forecast))))
end
