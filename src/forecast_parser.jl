
"""Describes how to construct forecasts from raw timeseries data files."""
mutable struct TimeseriesFileMetadata
    simulation::String  # User description of simulation
    category::String  # String version of abstract type for the forecasted component.
    # Calling module should determine the actual type.
    component_name::String  # Name of forecast component
    label::String  # Accessor function on component for source of timeseries
    scaling_factor::Union{String, Float64}  # Controls normalization of timeseries.
    # Use 1.0 for pre-normalized data.
    # Use 'Max' to divide the timeseries by the max
    #   value in the column.
    # Use any float for a custom scaling factor.
    data_file::String  # path to the timeseries data file
    percentiles::Vector{Float64}
    forecast_type::String
    component::Union{Nothing, InfrastructureSystemsType}  # Calling module must set.
end

function TimeseriesFileMetadata(
    simulation,
    category,
    component_name,
    label,
    scaling_factor,
    data_file,
    percentiles,
    forecast_type,
)
    return TimeseriesFileMetadata(
        simulation,
        category,
        component_name,
        label,
        scaling_factor,
        data_file,
        percentiles,
        forecast_type,
        nothing,
    )
end

"""Reads forecast metadata and fixes relative paths to the data files."""
function read_time_series_metadata(file_path::AbstractString)
    if endswith(file_path, ".json")
        metadata = open(file_path) do io
            metadata = Vector{TimeseriesFileMetadata}()
            data = JSON.parse(io)
            for item in data
                category = _get_category(item["category"])
                scaling_factor = item["scaling_factor"]
                if !isa(scaling_factor, AbstractString)
                    scaling_factor = Float64(scaling_factor)
                end
                push!(
                    metadata,
                    TimeseriesFileMetadata(
                        item["simulation"],
                        item["category"],
                        item["component_name"],
                        item["label"],
                        scaling_factor,
                        item["data_file"],
                        # Use default values until CDM data is updated.
                        get(item, "percentiles", []),
                        get(item, "forecast_type", "DeterministicInternal"),
                    ),
                )
            end
            return metadata
        end
    elseif endswith(file_path, ".csv")
        csv = CSV.read(file_path)
        metadata = Vector{TimeseriesFileMetadata}()
        for row in eachrow(csv)
            category = _get_category(row.Category)
            push!(
                metadata,
                TimeseriesFileMetadata(
                    row.simulation,
                    row.category,
                    row.component_name,
                    row.label,
                    row.scaling_factor,
                    row.data_file,
                    # TODO: update CDM data for the next
                    # two fields.
                    [],
                    "DeterministicInternal",
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

struct ForecastInfo
    simulation::String
    component::InfrastructureSystemsType
    label::String  # Component field on which timeseries data is based.
    scaling_factor::Union{String, Float64}
    data::TimeSeries.TimeArray
    percentiles::Vector{Float64}
    file_path::String
    forecast_type::String

    function ForecastInfo(
        simulation,
        component,
        label,
        scaling_factor,
        data,
        percentiles,
        file_path,
        forecast_type,
    )
        new(
            simulation,
            component,
            label,
            scaling_factor,
            data,
            percentiles,
            abspath(file_path),
            forecast_type,
        )
    end
end

function ForecastInfo(metadata::TimeseriesFileMetadata, timeseries::TimeSeries.TimeArray)
    return ForecastInfo(
        metadata.simulation,
        metadata.component,
        metadata.label,
        metadata.scaling_factor,
        timeseries,
        metadata.percentiles,
        metadata.data_file,
        metadata.forecast_type,
    )
end

function get_forecast_type(forecast_info::ForecastInfo)
    return getfield(InfrastructureSystems, Symbol(forecast_info.forecast_type))
end

struct ForecastCache
    forecasts::Vector{ForecastInfo}
    data_files::Dict{String, TimeSeries.TimeArray}
end

function ForecastCache()
    return ForecastCache(Vector{ForecastInfo}(), Dict{String, TimeSeries.TimeArray}())
end

function handle_scaling_factor(
    timeseries::TimeSeries.TimeArray,
    scaling_factor::Union{String, Float64},
)
    if scaling_factor isa String
        if lowercase(scaling_factor) == "max"
            max_value = maximum(TimeSeries.values(timeseries))
            timeseries = timeseries ./ max_value
            @debug "Normalize by max value" max_value
        else
            throw(DataFormatError("invalid scaling_factor=scaling_factor"))
        end
    elseif scaling_factor != 1.0
        timeseries = timeseries ./ scaling_factor
        @debug "Normalize by custom scaling factor" scaling_factor
    else
        @debug "forecast is already normalized"
    end

    return timeseries
end

function _add_forecast_info!(
    forecast_cache::ForecastCache,
    data_file::AbstractString,
    component_name::Union{Nothing, String},
)
    if !haskey(forecast_cache.data_files, data_file)
        forecast_cache.data_files[data_file] = read_time_series(data_file, component_name)
        @debug "Added timeseries file" data_file
    end

    return forecast_cache.data_files[data_file]
end
