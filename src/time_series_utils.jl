time_series_data_to_metadata(::Type{<:AbstractDeterministic}) = DeterministicMetadata
time_series_data_to_metadata(::Type{Probabilistic}) = ProbabilisticMetadata
time_series_data_to_metadata(::Type{Scenarios}) = ScenariosMetadata
time_series_data_to_metadata(::Type{SingleTimeSeries}) = SingleTimeSeriesMetadata

time_series_metadata_to_data(::ProbabilisticMetadata) = Probabilistic
time_series_metadata_to_data(::ScenariosMetadata) = Scenarios
time_series_metadata_to_data(::SingleTimeSeriesMetadata) = SingleTimeSeries

function time_series_metadata_to_data(ts_metadata::DeterministicMetadata)
    return ts_metadata.time_series_type
end

is_time_series_sub_type(::Type{<:TimeSeriesMetadata}, ::Type{<:TimeSeriesData}) = false
is_time_series_sub_type(::Type{SingleTimeSeriesMetadata}, ::Type{StaticTimeSeries}) = true
is_time_series_sub_type(::Type{DeterministicMetadata}, ::Type{AbstractDeterministic}) = true
is_time_series_sub_type(::Type{DeterministicMetadata}, ::Type{Forecast}) = true
is_time_series_sub_type(::Type{ProbabilisticMetadata}, ::Type{Forecast}) = true
is_time_series_sub_type(::Type{ScenariosMetadata}, ::Type{Forecast}) = true
