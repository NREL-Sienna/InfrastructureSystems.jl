"""Wraps the data read from the text files with time series"""
struct RawTimeSeries
    initial_time::Dates.DateTime
    data::Dict
end

"""Describes how to construct time_series from raw time series data files."""
mutable struct TimeSeriesFileMetadata
    "User description of simulation"
    simulation::String
    "String version of abstract type for the component associated with the time series."
    category::String
    "Calling module should determine the actual type."
    "Name of time_series component"
    component_name::String
    "User-defined name"
    name::String
    "Controls normalization of time series.
     Use 1.0 for pre-normalized data.
     Use 'Max' to divide the time series by the max value in the column.
     Use any float for a custom scaling factor."
    normalization_factor::Union{String, Float64}
    "Path to the time series data file"
    data_file::String
    "Resolution of the data being parsed in milliseconds"
    resolution::Dates.Period
    percentiles::Vector{Float64}
    time_series_type::DataType
    "Calling module must set."
    component::Union{Nothing, InfrastructureSystemsComponent}
    "Applicable when data are scaling factors. Accessor function on component to apply to
    values."
    scaling_factor_multiplier::Union{Nothing, String}
    scaling_factor_multiplier_module::Union{Nothing, String}
end

function TimeSeriesFileMetadata(;
    simulation,
    category,
    component_name,
    name,
    normalization_factor,
    data_file,
    resolution,
    percentiles,
    time_series_type_module,
    time_series_type,
    scaling_factor_multiplier = nothing,
    scaling_factor_multiplier_module = nothing,
)

    mod = Base.root_module(Base.__toplevel__, Symbol(time_series_type_module))
    ts_type = getfield(mod, Symbol(time_series_type))

    return TimeSeriesFileMetadata(
        simulation,
        category,
        component_name,
        name,
        normalization_factor,
        data_file,
        resolution,
        percentiles,
        ts_type,
        nothing,
        scaling_factor_multiplier,
        scaling_factor_multiplier_module,
    )
end

"""Reads time_series metadata and fixes relative paths to the data files."""
function read_time_series_file_metadata(file_path::AbstractString; resolution::Union{Dates.Period, Nothing} = nothing)
    if endswith(file_path, ".json")
        metadata = open(file_path) do io
            metadata = Vector{TimeSeriesFileMetadata}()
            data = JSON3.read(io, Array)
            for item in data
                parsed_resolution = Dates.Millisecond(item["resolution"])
                if resolution !== nothing && parsed_resolution != resolution
                    @debug "Skip time_series with resolution=$parsed_resolution; doesn't match user=$resolution"
                    continue
                end
                category = _get_category(item["category"])
                normalization_factor = item["normalization_factor"]
                if !isa(normalization_factor, AbstractString)
                    normalization_factor = Float64(normalization_factor)
                end
                scaling_factor_multiplier =
                    get(item, "scaling_factor_multiplier", nothing)
                scaling_factor_multiplier_module =
                    get(item, "scaling_factor_multiplier_module", nothing)
                push!(
                    metadata,
                    TimeSeriesFileMetadata(;
                        simulation = item["simulation"],
                        category = item["category"],
                        component_name = item["component_name"],
                        name = item["name"],
                        normalization_factor = normalization_factor,
                        data_file = item["data_file"],
                        parsed_resolution,
                        # Use default values until CDM data is updated.
                        percentiles = get(item, "percentiles", []),
                        time_series_type_module = get(
                            item,
                            "module",
                            "InfrastructureSystems",
                        ),
                        time_series_type = get(item, "type", "SingleTimeSeries"),
                        scaling_factor_multiplier = scaling_factor_multiplier,
                        scaling_factor_multiplier_module = scaling_factor_multiplier_module,
                    ),
                )
            end
            return metadata
        end
    elseif endswith(file_path, ".csv")
        csv = DataFrames.DataFrame(CSV.File(file_path))
        metadata = Vector{TimeSeriesFileMetadata}()
        for row in eachrow(csv)
            category = _get_category(row.category)
            scaling_factor_multiplier = get(row, :scaling_factor_multiplier, nothing)
            scaling_factor_multiplier_module =
                get(row, :scaling_factor_multiplier_module, nothing)
            push!(
                metadata,
                TimeSeriesFileMetadata(;
                    simulation = row.simulation,
                    category = row.category,
                    component_name = row.component_name,
                    name = row.name,
                    resolution = resolution,
                    normalization_factor = row.normalization_factor,
                    data_file = row.data_file,
                    percentiles = [],
                    time_series_type_module = get(row, :module, "InfrastructureSystems"),
                    time_series_type = get(row, :type, "SingleTimeSeries"),
                    scaling_factor_multiplier = scaling_factor_multiplier,
                    scaling_factor_multiplier_module = scaling_factor_multiplier_module,
                ),
            )
        end

    else
        error("file not supported")
    end

    directory = dirname(file_path)
    for ts_metadata in metadata
        ts_metadata.data_file = abspath(joinpath(directory, ts_metadata.data_file))
    end

    return metadata
end

function _get_category(category::String)
    # Re-mapping for PowerSystems RTS data.
    if category == "Area"
        category = "bus"
    end

    return lowercase(category)
end

@scoped_enum NormalizationType begin
    MAX
end

const NormalizationFactor = Union{Float64, NormalizationTypes.NormalizationType}

function handle_normalization_factor(
    data::AbstractDict,
    normalization_factor::NormalizationFactor,
)
    for (k, v) in data
        data[k] = handle_normalization_factor(v, normalization_factor)
    end
    return data
end

function handle_normalization_factor(
    ta::TimeSeries.TimeArray,
    normalization_factor::NormalizationFactor,
)
    if normalization_factor isa NormalizationTypes.NormalizationType
        max_value = maximum(TimeSeries.values(ta))
        ta = ta ./ max_value
        @debug "Normalize by max value" max_value
    else
        if normalization_factor != 1.0
            ta = ta ./ normalization_factor
            @debug "Normalize by custom scaling factor" normalization_factor
        else
            @debug "time_series is already normalized"
        end
    end

    return ta
end

struct TimeSeriesParsedInfo
    simulation::String
    component::InfrastructureSystemsComponent
    name::String  # Component field on which time series data is based.
    normalization_factor::NormalizationFactor
    data::RawTimeSeries
    initial_time::Dates.DateTime
    percentiles::Vector{Float64}
    file_path::String
    resolution::Dates.Period
    time_series_type::DataType
    scaling_factor_multiplier::Union{Nothing, Function}

    function TimeSeriesParsedInfo(
        simulation,
        component,
        name,
        normalization_factor,
        data,
        percentiles,
        file_path,
        time_series_type,
        scaling_factor_multiplier = nothing,
    )
        new(
            simulation,
            component,
            name,
            normalization_factor,
            data,
            percentiles,
            abspath(file_path),
            time_series_type,
            scaling_factor_multiplier,
        )
    end
end

function TimeSeriesParsedInfo(metadata::TimeSeriesFileMetadata, ta::TimeSeries.TimeArray)
    ts_type =
        get_type_from_strings(metadata.time_series_type_module, metadata.time_series_type)

    if (
        metadata.scaling_factor_multiplier === nothing &&
        metadata.scaling_factor_multiplier_module !== nothing
    ) || (
        metadata.scaling_factor_multiplier !== nothing &&
        metadata.scaling_factor_multiplier_module === nothing
    )
        throw(DataFormatError("scaling_factor_multiplier and scaling_factor_multiplier_module must both be set or not set"))
    end

    if metadata.scaling_factor_multiplier === nothing
        multiplier_func = nothing
    else
        multiplier_func = get_type_from_strings(
            metadata.scaling_factor_multiplier_module,
            metadata.scaling_factor_multiplier,
        )
    end

    if metadata.normalization_factor isa String
        if lowercase(metadata.normalization_factor) == "max"
            normalization_factor = NormalizationTypes.MAX
        else
            factor = metadata.normalization_factor
            throw(DataFormatError("unsupported normalization_factor {factor}"))
        end
    else
        normalization_factor = metadata.normalization_factor
    end

    return TimeSeriesParsedInfo(
        metadata.simulation,
        metadata.component,
        metadata.name,
        normalization_factor,
        ta,
        metadata.percentiles,
        metadata.data_file,
        metadata.time_series_type,
        multiplier_func,
    )
end

struct TimeSeriesCache
    time_series_infos::Vector{TimeSeriesParsedInfo}
    data_files::Dict{String, TimeSeries.TimeArray}
end

function TimeSeriesCache()
    return TimeSeriesCache(
        Vector{TimeSeriesParsedInfo}(),
        Dict{String, Any}(),
    )
end

function _add_time_series_info!(
    cache::TimeSeriesCache,
    metadata::TimeSeriesFileMetadata
)
    if !haskey(cache.data_files, metadata.data_file)
        cache.data_files[metadata.data_file] = read_time_series(metadata)
        @debug "Added time series file" metadata.data_file
    end
    return cache.data_files[metadata.data_file]
end
