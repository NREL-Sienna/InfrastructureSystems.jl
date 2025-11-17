"""
    mutable struct Scenarios <: Forecast
        name::String
        resolution::Dates.Period
        interval::Dates.Period
        scenario_count::Int
        data::SortedDict
        scaling_factor_multiplier::Union{Nothing, Function}
        internal::InfrastructureSystemsInternal
    end

A Discrete Scenario Based time series for a particular data field in a Component.

# Arguments

  - `name::String`: user-defined name
  - `resolution::Dates.Period`: forecast resolution
  - `interval::Dates.Period`: forecast interval
  - `scenario_count::Int`: Number of scenarios
  - `data::SortedDict`: timestamp - scalingfactor
  - `scaling_factor_multiplier::Union{Nothing, Function}`: Applicable when the time series
    data are scaling factors. Called on the associated component to convert the values.
  - `internal::InfrastructureSystemsInternal`
"""
mutable struct Scenarios <: Forecast
    "user-defined name"
    name::String
    "timestamp - scalingfactor"
    data::SortedDict  # TODO see note in Deterministic
    "Number of scenarios"
    scenario_count::Int
    "forecast resolution"
    resolution::Dates.Period
    "forecast interval"
    interval::Dates.Period
    "Applicable when the time series data are scaling factors. Called on the associated component to convert the values."
    scaling_factor_multiplier::Union{Nothing, Function}
    internal::InfrastructureSystemsInternal
end

function Scenarios(;
    name::String,
    data::SortedDict{Dates.DateTime, Matrix{Float64}},
    scenario_count::Int,
    resolution::Dates.Period,
    interval::Union{Nothing, Dates.Period} = nothing,
    scaling_factor_multiplier = nothing,
    normalization_factor = 1.0,
    internal = InfrastructureSystemsInternal(),
)
    data = handle_normalization_factor(data, normalization_factor)

    if isnothing(interval)
        interval = get_interval_from_initial_times(get_sorted_keys(data))
    end

    return Scenarios(
        name,
        data,
        scenario_count,
        resolution,
        interval,
        scaling_factor_multiplier,
        internal,
    )
end

"""
Construct Scenarios from a SortedDict of Arrays.

# Arguments

  - `name::String`: user-defined name
  - `input_data::SortedDict{Dates.DateTime, Matrix{Float64}}`: time series data.
  - `resolution::Dates.Period`: The resolution of the forecast in `Dates.Period`
  - `interval::Union{Nothing, Dates.Period}`: If nothing, infer interval from the
    data. Otherwise, this must be the difference in time between the start of each window.
    Interval is required if the type is irregular, such as with Dates.Month or Dates.Year.
  - `normalization_factor::NormalizationFactor = 1.0`: optional normalization factor to apply
    to each data entry
  - `scaling_factor_multiplier::Union{Nothing, Function} = nothing`: If the data are scaling
    factors then this function will be called on the component and applied to the data when
    [`get_time_series_array`](@ref) is called.
"""
function Scenarios(
    name::String,
    data::SortedDict{Dates.DateTime, Matrix{Float64}},
    resolution::Dates.Period;
    interval::Union{Nothing, Dates.Period} = nothing,
    normalization_factor::NormalizationFactor = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
)
    return Scenarios(;
        name = name,
        data = data,
        scenario_count = size(first(values(data)))[2],
        resolution = resolution,
        interval = interval,
        scaling_factor_multiplier = scaling_factor_multiplier,
        normalization_factor = normalization_factor,
        internal = InfrastructureSystemsInternal(),
    )
end

function Scenarios(
    name::String,
    data::AbstractDict{Dates.DateTime, Matrix{Float64}},
    resolution::Dates.Period;
    interval::Union{Nothing, Dates.Period} = nothing,
    normalization_factor::NormalizationFactor = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
)
    return Scenarios(
        name,
        SortedDict(data...),
        resolution;
        interval = interval,
        normalization_factor = normalization_factor,
        scaling_factor_multiplier = scaling_factor_multiplier,
    )
end

"""
Construct Scenarios from a Dict of TimeArrays.

# Arguments

  - `name::String`: user-defined name
  - `input_data::AbstractDict{Dates.DateTime, TimeSeries.TimeArray}`: time series data.
  - `resolution::Union{Nothing, Dates.Period} = nothing`: If nothing, infer resolution from
    the data. Otherwise, it must be the difference between each consecutive timestamps.
    Resolution is required if the type is irregular, such as with Dates.Month or Dates.Year.
  - `interval::Union{Nothing, Dates.Period} = nothing`: If nothing, infer interval from the
    data. Otherwise, it must be the difference in time between the start of each window.
    Interval is required if the type is irregular, such as with Dates.Month or Dates.Year.
  - `normalization_factor::NormalizationFactor = 1.0`: optional normalization factor to apply
    to each data entry
  - `scaling_factor_multiplier::Union{Nothing, Function} = nothing`: If the data are scaling
    factors then this function will be called on the component and applied to the data when
    [`get_time_series_array`](@ref) is called.
  - `timestamp = :timestamp`: If the values are DataFrames is passed then this must be the column name that
    contains timestamps.
"""
function Scenarios(
    name::String,
    input_data::AbstractDict{Dates.DateTime, <:TimeSeries.TimeArray};
    resolution::Union{Nothing, Dates.Period} = nothing,
    interval::Union{Nothing, Dates.Period} = nothing,
    normalization_factor::NormalizationFactor = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
)
    data, res = convert_forecast_input_time_arrays(input_data; resolution = resolution)
    return Scenarios(;
        name = name,
        data = data,
        resolution = res,
        interval = interval,
        scenario_count = size(first(values(input_data)))[2],
        normalization_factor = normalization_factor,
        scaling_factor_multiplier = scaling_factor_multiplier,
    )
end

"""
Construct Scenarios that shares the data from an existing instance.

This is useful in cases where you want a component to use the same time series data for
two different attributes.
"""
function Scenarios(
    src::Scenarios,
    name::String;
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
)
    # units and ext are not copied
    internal = InfrastructureSystemsInternal(; uuid = get_uuid(src))
    return Scenarios(
        name,
        src.data,
        src.scenario_count,
        src.resolution,
        src.interval,
        scaling_factor_multiplier,
        internal,
    )
end

function Scenarios(ts_metadata::ScenariosMetadata, data::SortedDict)
    return Scenarios(;
        name = get_name(ts_metadata),
        scenario_count = get_scenario_count(ts_metadata),
        resolution = get_resolution(ts_metadata),
        interval = get_interval(ts_metadata),
        data = data,
        scaling_factor_multiplier = get_scaling_factor_multiplier(ts_metadata),
        internal = InfrastructureSystemsInternal(get_time_series_uuid(ts_metadata)),
    )
end

# Note: interval is not support in this workflow.

function Scenarios(info::TimeSeriesParsedInfo)
    return Scenarios(
        info.name,
        info.data,
        info.resolution;
        normalization_factor = info.normalization_factor,
        scaling_factor_multiplier = info.scaling_factor_multiplier,
    )
end

function ScenariosMetadata(time_series::Scenarios; features...)
    return ScenariosMetadata(
        get_name(time_series),
        get_resolution(time_series),
        get_initial_timestamp(time_series),
        get_interval(time_series),
        get_scenario_count(time_series),
        get_count(time_series),
        get_uuid(time_series),
        get_horizon(time_series),
        get_scaling_factor_multiplier(time_series),
        Dict{String, Any}(string(k) => v for (k, v) in features),
    )
end

function get_array_for_hdf(forecast::Scenarios)
    interval_count = get_count(forecast)
    scenario_count = get_scenario_count(forecast)
    horizon_count = get_horizon_count(forecast)
    data = get_data(forecast)

    data_for_hdf = Array{Float64, 3}(undef, scenario_count, horizon_count, interval_count)
    for (ix, f) in enumerate(values(data))
        data_for_hdf[:, :, ix] = transpose(f)
    end
    return data_for_hdf
end

"""
Get [`Scenarios`](@ref) `name`.
"""
@inline get_name(value::Scenarios) = value.name
"""
Get [`Scenarios`](@ref) `resolution`.
"""
@inline get_resolution(value::Scenarios) = value.resolution
"""
Get [`Scenarios`](@ref) `interval`.
"""
@inline get_interval(value::Scenarios) = value.interval
"""
Get [`Scenarios`](@ref) `scenario_count`.
"""
@inline get_scenario_count(value::Scenarios) = value.scenario_count
"""
Get [`Scenarios`](@ref) `data`.
"""
@inline get_data(value::Scenarios) = value.data
"""
Get [`Scenarios`](@ref) `scaling_factor_multiplier`.
"""
@inline get_scaling_factor_multiplier(value::Scenarios) = value.scaling_factor_multiplier
"""
Get [`Scenarios`](@ref) `internal`.
"""
@inline get_internal(value::Scenarios) = value.internal
"""
Set [`Scenarios`](@ref) `name`.
"""
@inline set_name!(value::Scenarios, val) = value.name = val
"""
Set [`Scenarios`](@ref) `resolution`.
"""
@inline set_resolution!(value::Scenarios, val) = value.resolution = val
"""
Set [`Scenarios`](@ref) `scenario_count`.
"""
@inline set_scenario_count!(value::Scenarios, val) = value.scenario_count = val
"""
Set [`Scenarios`](@ref) `data`.
"""
@inline set_data!(value::Scenarios, val) = value.data = val
"""
Set [`Scenarios`](@ref) `scaling_factor_multiplier`.
"""
@inline set_scaling_factor_multiplier!(value::Scenarios, val) =
    value.scaling_factor_multiplier = val
"""
Set [`Scenarios`](@ref) `internal`.
"""
@inline set_internal!(value::Scenarios, val) = value.internal = val

# TODO see Deterministic
eltype_data(forecast::Scenarios) = eltype_data_common(forecast)
get_initial_times(forecast::Scenarios) = get_initial_times_common(forecast)
get_initial_timestamp(forecast::Scenarios) = get_initial_timestamp_common(forecast)
get_window(f::Scenarios, initial_time::Dates.DateTime; len = nothing) =
    get_window_common(f, initial_time; len = len)

"""
Iterate over the windows in a forecast

# Examples
```julia
for window in iterate_windows(forecast)
    @show values(maximum(window))
end
```
"""
iterate_windows(forecast::Scenarios) = iterate_windows_common(forecast)
