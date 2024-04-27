mutable struct TimeSeriesManager <: InfrastructureSystemsType
    data_store::TimeSeriesStorage
    metadata_store::TimeSeriesMetadataStore
    read_only::Bool
end

function TimeSeriesManager(;
    data_store = nothing,
    metadata_store = nothing,
    in_memory = false,
    read_only = false,
    directory = nothing,
    compression = CompressionSettings(),
)
    if isnothing(directory) && haskey(ENV, TIME_SERIES_DIRECTORY_ENV_VAR)
        directory = ENV[TIME_SERIES_DIRECTORY_ENV_VAR]
    end

    if isnothing(metadata_store)
        metadata_store = TimeSeriesMetadataStore()
    end

    if isnothing(data_store)
        data_store = make_time_series_storage(;
            in_memory = in_memory,
            directory = directory,
            compression = compression,
        )
    end
    return TimeSeriesManager(data_store, metadata_store, read_only)
end

get_database(mgr::TimeSeriesManager) = mgr.metadata_store.db

function add_time_series!(
    mgr::TimeSeriesManager,
    owner::TimeSeriesOwners,
    time_series::TimeSeriesData;
    skip_if_present = false,
    features...,
)
    _throw_if_read_only(mgr)
    throw_if_does_not_support_time_series(owner)
    _check_time_series_params(mgr, time_series)
    metadata_type = time_series_data_to_metadata(typeof(time_series))
    metadata = metadata_type(time_series; features...)
    data_exists = has_time_series(mgr.metadata_store, get_uuid(time_series))
    metadata_exists = has_metadata(mgr.metadata_store, owner, metadata)

    if metadata_exists && !skip_if_present
        msg = if isempty(features)
            "$(summary(metadata)) is already stored"
        else
            fmsg = join(["$k = $v" for (k, v) in features], ", ")
            "$(summary(metadata)) with features $fmsg is already stored"
        end
        throw(ArgumentError(msg))
    end

    if !data_exists
        serialize_time_series!(mgr.data_store, time_series)
    end

    # Order matters. Don't add metadata unless serialize works.
    if !metadata_exists
        add_metadata!(
            mgr.metadata_store,
            owner,
            metadata;
        )
    end
    @debug "Added $(summary(metadata)) to $(summary(owner)) " _group =
        LOG_GROUP_TIME_SERIES
    return
end

function clear_time_series!(mgr::TimeSeriesManager)
    _throw_if_read_only(mgr)
    clear_metadata!(mgr.metadata_store)
    clear_time_series!(mgr.data_store)
end

function clear_time_series!(mgr::TimeSeriesManager, component::TimeSeriesOwners)
    _throw_if_read_only(mgr)
    for metadata in list_metadata(mgr.metadata_store, component)
        remove_time_series!(mgr, component, metadata)
    end
    @debug "Cleared time_series in $(summary(component))." _group =
        LOG_GROUP_TIME_SERIES
    return
end

has_time_series(mgr::TimeSeriesManager, component::TimeSeriesOwners) =
    has_time_series(mgr.metadata_store, component)
has_time_series(::Nothing, component::TimeSeriesOwners) = false

function Base.deepcopy_internal(mgr::TimeSeriesManager, dict::IdDict)
    if haskey(dict, mgr)
        return dict[mgr]
    end
    data_store = deepcopy(mgr.data_store)
    if mgr.data_store isa Hdf5TimeSeriesStorage
        copy_to_new_file!(data_store, dirname(mgr.data_store.file_path))
    end

    new_db_file = backup_to_temp(mgr.metadata_store)
    metadata_store = TimeSeriesMetadataStore(new_db_file)
    new_mgr = TimeSeriesManager(data_store, metadata_store, mgr.read_only)
    dict[mgr] = new_mgr
    dict[mgr.data_store] = new_mgr.data_store
    dict[mgr.metadata_store] = new_mgr.metadata_store
    return new_mgr
end

get_metadata(
    mgr::TimeSeriesManager,
    component::TimeSeriesOwners,
    time_series_type::Type{<:TimeSeriesData},
    name::String;
    features...,
) = get_metadata(
    mgr.metadata_store,
    component,
    time_series_type,
    name;
    features...,
)

list_metadata(
    mgr::TimeSeriesManager,
    component::TimeSeriesOwners;
    time_series_type::Union{Type{<:TimeSeriesData}, Nothing} = nothing,
    name::Union{String, Nothing} = nothing,
    features...,
) = list_metadata(
    mgr.metadata_store,
    component;
    time_series_type = time_series_type,
    name = name,
    features...,
)

"""
Remove the time series data for a component.
"""
function remove_time_series!(
    mgr::TimeSeriesManager,
    time_series_type::Type{<:TimeSeriesData},
    owner::TimeSeriesOwners,
    name::String;
    features...,
)
    _throw_if_read_only(mgr)
    uuids = list_matching_time_series_uuids(
        mgr.metadata_store;
        time_series_type = time_series_type,
        name = name,
        features...,
    )
    remove_metadata!(
        mgr.metadata_store,
        owner;
        time_series_type = time_series_type,
        name = name,
        features...,
    )

    @debug "Removed time_series metadata in $(summary(component))." _group =
        LOG_GROUP_TIME_SERIES component time_series_type name features

    for uuid in uuids
        _remove_data_if_no_more_references(mgr, uuid)
    end

    return
end

function remove_time_series!(
    mgr::TimeSeriesManager,
    owner::TimeSeriesOwners,
    metadata::TimeSeriesMetadata,
)
    _throw_if_read_only(mgr)
    remove_metadata!(mgr.metadata_store, owner, metadata)
    @debug "Removed time_series metadata in $(summary(owner)) $(summary(metadata))." _group =
        LOG_GROUP_TIME_SERIES
    _remove_data_if_no_more_references(mgr, get_time_series_uuid(metadata))
    return
end

function _check_time_series_params(mgr::TimeSeriesManager, ts::StaticTimeSeries)
    check_params_compatibility(mgr.metadata_store, StaticTimeSeriesParameters())
    data = get_data(ts)
    if length(data) < 2
        throw(ArgumentError("data array length must be at least 2: $(length(data))"))
    end
    if length(data) != length(ts)
        throw(ConflictingInputsError("length mismatch: $(length(data)) $(length(ts))"))
    end

    timestamps = TimeSeries.timestamp(data)
    difft = timestamps[2] - timestamps[1]
    if difft != get_resolution(ts)
        throw(ConflictingInputsError("resolution mismatch: $difft $(get_resolution(ts))"))
    end
    return
end

function _check_time_series_params(mgr::TimeSeriesManager, ts::Forecast)
    check_params_compatibility(
        mgr.metadata_store,
        ForecastParameters(;
            horizon = get_horizon(ts),
            initial_timestamp = get_initial_timestamp(ts),
            interval = get_interval(ts),
            count = get_count(ts),
            resolution = get_resolution(ts),
        ),
    )
    horizon = get_horizon(ts)
    if horizon < 2
        throw(ArgumentError("horizon must be at least 2: $horizon"))
    end
    for window in iterate_windows(ts)
        if size(window)[1] != horizon
            throw(ConflictingInputsError("length mismatch: $(size(window)[1]) $horizon"))
        end
    end
end

function _remove_data_if_no_more_references(mgr::TimeSeriesManager, uuid::Base.UUID)
    if !has_time_series(mgr.metadata_store, uuid)
        remove_time_series!(mgr.data_store, uuid)
        @debug "Removed time_series data $uuid." _group = LOG_GROUP_TIME_SERIES
    end

    return
end

function _throw_if_read_only(mgr::TimeSeriesManager)
    if mgr.read_only
        throw(ArgumentError("Time series operation is not allowed in read-only mode."))
    end
end

function compare_values(
    x::TimeSeriesManager,
    y::TimeSeriesManager;
    compare_uuids = false,
    exclude = Set{Symbol}(),
)
    match = true
    for name in fieldnames(TimeSeriesManager)
        val_x = getproperty(x, name)
        val_y = getproperty(y, name)
        if name == :data_store && typeof(val_x) != typeof(val_y)
            @warn "Cannot compare $(typeof(val_x)) and $(typeof(val_y))"
            # TODO 1.0: workaround for not being able to convert Hdf5TimeSeriesStorage to
            # InMemoryTimeSeriesStorage
            continue
        elseif name == :read_only
            # Skip this because users can change it during deserialization and we test it
            # separately.
            continue
        end

        if !compare_values(val_x, val_y; compare_uuids = compare_uuids, exclude = exclude)
            @error "TimeSeriesManager field = $name does not match" getproperty(x, name) getproperty(
                y,
                name,
            )
            match = false
        end
    end

    return match
end
