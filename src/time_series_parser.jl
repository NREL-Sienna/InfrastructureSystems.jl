"""Describes how to construct time_series from raw time series data files."""
mutable struct TimeSeriesFileMetadata
    simulation::String  # User description of simulation
    category::String  # String version of abstract type for the time_seriesed component.
    # Calling module should determine the actual type.
    component_name::String  # Name of time_series component
    label::String  # Accessor function on component for source of time series
    scaling_factor::Union{String, Float64}  # Controls normalization of time series.
    # Use 1.0 for pre-normalized data.
    # Use 'Max' to divide the time series by the max
    #   value in the column.
    # Use any float for a custom scaling factor.
    data_file::String  # path to the time series data file
    percentiles::Vector{Float64}
    time_series_type::String
    component::Union{Nothing, InfrastructureSystemsComponent}  # Calling module must set.
end

function TimeSeriesFileMetadata(
    simulation,
    category,
    component_name,
    label,
    scaling_factor,
    data_file,
    percentiles,
    time_series_type,
)
    return TimeSeriesFileMetadata(
        simulation,
        category,
        component_name,
        label,
        scaling_factor,
        data_file,
        percentiles,
        time_series_type,
        nothing,
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
                scaling_factor = item["scaling_factor"]
                if !isa(scaling_factor, AbstractString)
                    scaling_factor = Float64(scaling_factor)
                end
                push!(
                    metadata,
                    TimeSeriesFileMetadata(
                        item["simulation"],
                        item["category"],
                        item["component_name"],
                        item["label"],
                        scaling_factor,
                        item["data_file"],
                        # Use default values until CDM data is updated.
                        get(item, "percentiles", []),
                        get(item, "time_series_type", "DeterministicMetadata"),
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
            push!(
                metadata,
                TimeSeriesFileMetadata(
                    row.simulation,
                    row.category,
                    row.component_name,
                    row.label,
                    row.scaling_factor,
                    row.data_file,
                    # TODO: update CDM data for the next
                    # two fields.
                    [],
                    "DeterministicMetadata",
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

struct TimeSeriesParserInfo
    simulation::String
    component::InfrastructureSystemsComponent
    label::String  # Component field on which time series data is based.
    scaling_factor::Union{String, Float64}
    data::TimeSeries.TimeArray
    percentiles::Vector{Float64}
    file_path::String
    time_series_type::String

    function TimeSeriesParserInfo(
        simulation,
        component,
        label,
        scaling_factor,
        data,
        percentiles,
        file_path,
        time_series_type,
    )
        new(
            simulation,
            component,
            label,
            scaling_factor,
            data,
            percentiles,
            abspath(file_path),
            time_series_type,
        )
    end
end

function TimeSeriesParserInfo(metadata::TimeSeriesFileMetadata, ta::TimeSeries.TimeArray)
    return TimeSeriesParserInfo(
        metadata.simulation,
        metadata.component,
        metadata.label,
        metadata.scaling_factor,
        ta,
        metadata.percentiles,
        metadata.data_file,
        metadata.time_series_type,
    )
end

function get_time_series_type(time_series_info::TimeSeriesParserInfo)
    return getfield(InfrastructureSystems, Symbol(time_series_info.time_series_type))
end

struct TimeSeriesCache
    time_series::Vector{TimeSeriesParserInfo}
    data_files::Dict{String, TimeSeries.TimeArray}
end

function TimeSeriesCache()
    return TimeSeriesCache(
        Vector{TimeSeriesParserInfo}(),
        Dict{String, TimeSeries.TimeArray}(),
    )
end

function handle_scaling_factor(
    ta::TimeSeries.TimeArray,
    scaling_factor::Union{String, Float64},
)
    if scaling_factor isa String
        if lowercase(scaling_factor) == "max"
            max_value = maximum(TimeSeries.values(ta))
            ta = ta ./ max_value
            @debug "Normalize by max value" max_value
        else
            throw(DataFormatError("invalid scaling_factor=scaling_factor"))
        end
    elseif scaling_factor != 1.0
        ta = ta ./ scaling_factor
        @debug "Normalize by custom scaling factor" scaling_factor
    else
        @debug "time_series is already normalized"
    end

    return ta
end

function _add_time_series_info!(
    time_series_cache::TimeSeriesCache,
    data_file::AbstractString,
    component_name::Union{Nothing, String},
)
    if !haskey(time_series_cache.data_files, data_file)
        time_series_cache.data_files[data_file] =
            read_time_series(data_file, component_name)
        @debug "Added time series file" data_file
    end

    return time_series_cache.data_files[data_file]
end
