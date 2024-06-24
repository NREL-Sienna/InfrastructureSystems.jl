# This is used to add time series associations efficiently in SQLite.
# This strikes a balance in SQLite efficiency vs loading many time arrays into memory.
const ADD_TIME_SERIES_BATCH_SIZE = 100

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

function bulk_add_time_series!(
    mgr::TimeSeriesManager,
    associations;
    batch_size = ADD_TIME_SERIES_BATCH_SIZE,
)
    ts_keys = TimeSeriesKey[]
    batch = TimeSeriesAssociation[]
    sizehint!(batch, batch_size)
    open_store!(mgr.data_store, "r+") do
        for association in associations
            push!(batch, association)
            if length(batch) >= batch_size
                append!(ts_keys, add_time_series!(mgr, batch))
                empty!(batch)
            end
        end

        if !isempty(batch)
            append!(ts_keys, add_time_series!(mgr, batch))
        end
    end

    return ts_keys
end

function add_time_series!(mgr::TimeSeriesManager, batch::Vector{TimeSeriesAssociation})
    _throw_if_read_only(mgr)
    forecast_params = get_forecast_parameters(mgr.metadata_store)
    sts_params = StaticTimeSeriesParameters()
    num_metadata = length(batch)
    all_metadata = Vector{TimeSeriesMetadata}(undef, num_metadata)
    owners = Vector{TimeSeriesOwners}(undef, num_metadata)
    ts_keys = Vector{TimeSeriesKey}(undef, num_metadata)
    time_series_uuids = Dict{Base.UUID, TimeSeriesData}()
    metadata_identifiers = Set{Tuple}()
    TimerOutputs.@timeit_debug SYSTEM_TIMERS "add_time_series! in bulk" begin
        for (i, item) in enumerate(batch)
            throw_if_does_not_support_time_series(item.owner)
            metadata_type = time_series_data_to_metadata(typeof(item.time_series))
            metadata = metadata_type(item.time_series; item.features...)
            identifier = make_unique_owner_metadata_identifer(item.owner, metadata)
            if identifier in metadata_identifiers
                throw(ArgumentError("$identifier is present multiple times"))
            end
            push!(metadata_identifiers, identifier)
            if isnothing(forecast_params)
                forecast_params = _get_forecast_params(item.time_series)
            end
            check_params_compatibility(sts_params, forecast_params, item.time_series)
            all_metadata[i] = metadata
            owners[i] = item.owner
            ts_keys[i] = make_time_series_key(metadata)
            time_series_uuids[get_uuid(item.time_series)] = item.time_series
        end

        uuids = keys(time_series_uuids)
        existing_ts_uuids = if isempty(uuids)
            Base.UUID[]
        else
            list_existing_time_series_uuids(mgr.metadata_store, uuids)
        end
        new_ts_uuids = setdiff(keys(time_series_uuids), existing_ts_uuids)

        existing_metadata = list_existing_metadata(mgr.metadata_store, owners, all_metadata)
        if !isempty(existing_metadata)
            throw(
                ArgumentError(
                    "Time series data with duplicate attributes are already stored: " *
                    "$(existing_metadata)",
                ),
            )
        end
        for uuid in new_ts_uuids
            serialize_time_series!(mgr.data_store, time_series_uuids[uuid])
        end
        add_metadata!(mgr.metadata_store, owners, all_metadata)
    end
    return ts_keys
end

_get_forecast_params(ts::Forecast) = make_time_series_parameters(ts)
_get_forecast_params(::StaticTimeSeries) = nothing

function add_time_series!(
    mgr::TimeSeriesManager,
    owner::TimeSeriesOwners,
    time_series::TimeSeriesData;
    features...,
)
    return add_time_series!(
        mgr,
        [TimeSeriesAssociation(owner, time_series; features...)],
    )[1]
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
