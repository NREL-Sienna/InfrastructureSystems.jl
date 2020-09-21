"""Describes how to construct time_series from raw time series data files."""
mutable struct TimeSeriesFileMetadata
    "User description of simulation"
    simulation::String
    "String version of abstract type for the component associated with the time series."
    category::String
    "Calling module should determine the actual type."
    "Name of time_series component"
    component_name::String
    "User-defined label"
    label::String
    "Controls normalization of time series.
     Use 1.0 for pre-normalized data.
     Use 'Max' to divide the time series by the max value in the column.
     Use any float for a custom scaling factor."
    normalization_factor::Union{String, Float64}
    "Path to the time series data file"
    data_file::String
    percentiles::Vector{Float64}
    time_series_type_module::String
    time_series_type::String
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
    label,
    normalization_factor,
    data_file,
    percentiles,
    time_series_type_module,
    time_series_type,
    scaling_factor_multiplier = nothing,
    scaling_factor_multiplier_module = nothing,
)
    return TimeSeriesFileMetadata(
        simulation,
        category,
        component_name,
        label,
        normalization_factor,
        data_file,
        percentiles,
        time_series_type_module,
        time_series_type,
        nothing,
        scaling_factor_multiplier,
        scaling_factor_multiplier_module,
    )
end

"""Reads time_series metadata and fixes relative paths to the data files."""
function read_time_series_file_metadata(file_path::AbstractString)
    if endswith(file_path, ".json")
        metadata = open(file_path) do io
            metadata = Vector{TimeSeriesFileMetadata}()
            data = JSON3.read(io, Array)
            for item in data
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
                        label = item["label"],
                        normalization_factor = normalization_factor,
                        data_file = item["data_file"],
                        # Use default values until CDM data is updated.
                        percentiles = get(item, "percentiles", []),
                        time_series_type_module = get(
                            item,
                            "module",
                            "InfrastructureSystems",
                        ),
                        time_series_type = get(item, "type", "Deterministic"),
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
                    label = row.label,
                    normalization_factor = row.normalization_factor,
                    data_file = row.data_file,
                    percentiles = [],
                    time_series_type_module = get(row, :module, "InfrastructureSystems"),
                    time_series_type = get(row, :type, "Deterministic"),
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
    label::String  # Component field on which time series data is based.
    normalization_factor::NormalizationFactor
    data::TimeSeries.TimeArray
    percentiles::Vector{Float64}
    file_path::String
    time_series_type::DataType
    scaling_factor_multiplier::Union{Nothing, Function}

    function TimeSeriesParsedInfo(
        simulation,
        component,
        label,
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
            label,
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
    mod = Base.root_module(Base.__toplevel__, Symbol(metadata.time_series_type_module))
    ts_type = time_series_data_to_metadata(getfield(mod, Symbol(metadata.time_series_type)))

    if (
        metadata.scaling_factor_multiplier === nothing &&
        metadata.scaling_factor_multiplier_module !== nothing
    ) || (
        metadata.scaling_factor_multiplier !== nothing &&
        metadata.scaling_factor_multiplier_module === nothing
    )
        throw(DataFormatError("scaling_factor_multiplier and scaling_factor_multiplier_module must both be set or not set"))
    end

    if metadata.scaling_factor_multiplier !== nothing
        multiplier_mod = Base.root_module(
            Base.__toplevel__,
            Symbol(metadata.scaling_factor_multiplier_module),
        )
        multiplier_func = metadata.scaling_factor_multiplier === nothing ? nothing :
            getfield(multiplier_mod, Symbol(metadata.scaling_factor_multiplier))
    else
        multiplier_func = nothing
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
        metadata.label,
        normalization_factor,
        ta,
        metadata.percentiles,
        metadata.data_file,
        ts_type,
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
        Dict{String, TimeSeries.TimeArray}(),
    )
end

function _add_time_series_info!(
    cache::TimeSeriesCache,
    data_file::AbstractString,
    component_name::Union{Nothing, String},
)
    if !haskey(cache.data_files, data_file)
        cache.data_files[data_file] = read_time_series(data_file, component_name)
        @debug "Added time series file" data_file
    end

    return cache.data_files[data_file]
end
