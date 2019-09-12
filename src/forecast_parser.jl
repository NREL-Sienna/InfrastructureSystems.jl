
"""Describes how to construct forecasts from raw timeseries data files."""
mutable struct TimeseriesFileMetadata
    simulation::String  # User description of simulation
    category::String  # String version of PowerSystems abstract type for forecast component.
                      # Refer to CATEGORY_STR_TO_COMPONENT.
    component_name::String  # Name of forecast component
    label::String  # Raw data column for source of timeseries
    scaling_factor::Union{String, Float64}  # Controls normalization of timeseries.
                                            # Use 1.0 for pre-normalized data.
                                            # Use 'Max' to divide the timeseries by the max
                                            #   value in the column.
                                            # Use any float for a custom scaling factor.
    data_file::String  # path to the timeseries data file
    percentiles::Vector{Float64}
    forecast_type::String
end

"""Reads forecast metadata and fixes relative paths to the data files."""
function read_timeseries_metadata(file_path::AbstractString)::Vector{TimeseriesFileMetadata}
    if endswith(file_path, ".json")
        metadata = open(file_path) do io
            metadata = Vector{TimeseriesFileMetadata}()
            data = JSON.parse(io)
            for item in data
                scaling_factor = item["scaling_factor"]
                if !isa(scaling_factor, AbstractString)
                    scaling_factor = Float64(scaling_factor)
                end
                push!(metadata, TimeseriesFileMetadata(
                    item["simulation"],
                    item["category"],
                    item["component_name"],
                    item["label"],
                    scaling_factor,
                    item["data_file"],
                    # Use default values until CDM data is updated.
                    get(item, "percentiles", []),
                    get(item, "forecast_type", "Deterministic"),
                ))
            end
            return metadata
        end
    elseif endswith(file_path, ".csv")
        csv = CSV.read(file_path)
        metadata = Vector{TimeseriesFileMetadata}()
        for row in eachrow(csv)
            push!(metadata, TimeseriesFileMetadata(row.Simulation,
                                                   row.Category,
                                                   row.Object,
                                                   row.Parameter,
                                                   row[Symbol("Scaling Factor")],
                                                   row[Symbol("Data File")],
                                                   row[Symbol("Percentiles")],
                                                  )
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

struct ForecastInfo
    simulation::String
    component::InfrastructureSystemsType
    label::String  # Component field on which timeseries data is based.
    scaling_factor::Union{String, Float64}
    data::TimeSeries.TimeArray
    percentiles::Vector{Float64}
    file_path::String
    forecast_type::String

    function ForecastInfo(simulation, component, label, scaling_factor, data, percentiles,
                          file_path, forecast_type)
        new(simulation, component, label, scaling_factor, data, percentiles,
            abspath(file_path), forecast_type)
    end
end

function ForecastInfo(metadata::TimeseriesFileMetadata,
                      component::InfrastructureSystemsType,
                      timeseries::TimeSeries.TimeArray)
    return ForecastInfo(metadata.simulation, component, metadata.label,
                        metadata.scaling_factor, timeseries, metadata.percentiles,
                        metadata.data_file, metadata.forecast_type)
end

function get_forecast_type(forecast_info::ForecastInfo)
    return getfield(InfrastructureSystems, Symbol(forecast_info.forecast_type))
end

struct ForecastInfos
    forecasts::Vector{ForecastInfo}
    data_files::Dict{String, TimeSeries.TimeArray}
end

function ForecastInfos()
    return ForecastInfos(Vector{ForecastInfo}(),
                         Dict{String, TimeSeries.TimeArray}())
end

function _handle_scaling_factor(timeseries::TimeSeries.TimeArray,
                                scaling_factor::Union{String, Float64})
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

function _get_category(metadata::TimeseriesFileMetadata, mod)
    # TODO: need to fix CDM data
    category = metadata.category == "LoadZone" ? :LoadZones : Symbol(metadata.category)
    return getfield(mod, category)
end

function _add_forecast_info!(infos::ForecastInfos, data_file::AbstractString,
                             component_name::Union{Nothing, String})
    if !haskey(infos.data_files, data_file)
        infos.data_files[data_file] = read_timeseries(data_file, component_name)
        @debug "Added timeseries file" data_file
    end

    return infos.data_files[data_file]
end
