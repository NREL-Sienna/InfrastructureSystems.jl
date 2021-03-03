const _TS_DATA_TO_METADATA_MAP = Dict(
    Deterministic => DeterministicMetadata,
    DeterministicSingleTimeSeries => DeterministicMetadata,
    AbstractDeterministic => DeterministicMetadata,
    Probabilistic => ProbabilisticMetadata,
    Scenarios => ScenariosMetadata,
    SingleTimeSeries => SingleTimeSeriesMetadata,
)

const _TS_METADATA_TO_DATA_MAP = Dict(
    # DeterministicMetadata is used for two types, and so this cannot be used for it.
    ProbabilisticMetadata => Probabilistic,
    ScenariosMetadata => Scenarios,
    SingleTimeSeriesMetadata => SingleTimeSeries,
)

function time_series_data_to_metadata(::Type{T}) where {T <: TimeSeriesData}
    return _TS_DATA_TO_METADATA_MAP[T]
end

function time_series_metadata_to_data(ts_metadata::TimeSeriesMetadata)
    return _TS_METADATA_TO_DATA_MAP[typeof(ts_metadata)]
end

function time_series_metadata_to_data(ts_metadata::DeterministicMetadata)
    return ts_metadata.time_series_type
end
