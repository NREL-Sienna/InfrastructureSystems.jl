const METADATA_TABLE_NAME = "time_series_metadata"
const DB_FILENAME = "time_series_metadata.db"

mutable struct TimeSeriesMetadataStore
    db::SQLite.DB
    # If you add any fields, ensure they are managed in deepcopy_internal below.
end

"""
Construct a new TimeSeriesMetadataStore with an in-memory database.
"""
function TimeSeriesMetadataStore()
    # This metadata is not expected to exceed system memory, so create an in-memory
    # database so that it is faster. This could be changed.
    store = TimeSeriesMetadataStore(SQLite.DB())
    _create_metadata_table!(store)
    _create_indexes!(store)
    @debug "Initialized new time series metadata table" _group = LOG_GROUP_TIME_SERIES
    return store
end

"""
Load a TimeSeriesMetadataStore from a saved database into an in-memory database.
"""
function TimeSeriesMetadataStore(filename::AbstractString)
    src = SQLite.DB(filename)
    db = SQLite.DB()
    backup(db, src)
    store = TimeSeriesMetadataStore(db)
    @debug "Loaded time series metadata from file" _group = LOG_GROUP_TIME_SERIES filename
    return store
end

"""
Load a TimeSeriesMetadataStore from an HDF5 file into an in-memory database.
"""
function from_h5_file(::Type{TimeSeriesMetadataStore}, src::AbstractString, directory)
    data = HDF5.h5open(src, "r") do file
        file[HDF5_TS_METADATA_ROOT_PATH][:]
    end

    filename, io = mktemp(isnothing(directory) ? tempdir() : directory)
    write(io, data)
    close(io)
    return TimeSeriesMetadataStore(filename)
end

function _create_metadata_table!(store::TimeSeriesMetadataStore)
    # TODO: SQLite createtable!() doesn't provide a way to create a primary key.
    # https://github.com/JuliaDatabases/SQLite.jl/issues/286
    # We can use that function if they ever add the feature.
    schema = [
        "id INTEGER PRIMARY KEY",
        "time_series_uuid TEXT NOT NULL",
        "time_series_type TEXT NOT NULL",
        "time_series_category TEXT NOT NULL",
        "initial_timestamp TEXT NOT NULL",
        "resolution_ms INTEGER NOT NULL",
        "horizon_ms INTEGER",
        "interval_ms INTEGER",
        "window_count INTEGER",
        "length INTEGER",
        "name TEXT NOT NULL",
        "owner_uuid TEXT NOT NULL",
        "owner_type TEXT NOT NULL",
        "owner_category TEXT NOT NULL",
        "features TEXT NOT NULL",
        # The metadata is included as a convenience for serialization/de-serialization,
        # specifically for types and their modules: time_series_type and scaling_factor_mulitplier.
        # There is duplication of data, but it saves a lot of code.
        "metadata JSON NOT NULL",
    ]
    schema_text = join(schema, ",")
    _execute(store, "CREATE TABLE $(METADATA_TABLE_NAME)($(schema_text))")
    @debug "Created time series metadata table" schema _group = LOG_GROUP_TIME_SERIES
    return
end

function _create_indexes!(store::TimeSeriesMetadataStore)
    # Index strategy:
    # 1. Optimize for these user queries with indexes:
    #    1a. all time series attached to one component/attribute
    #    1b. time series for one component/attribute + name + type
    #    1c. time series for one component/attribute with all features
    # 2. Optimize for checks at system.add_time_series. Use all fields and features.
    # 3. Optimize for returning all metadata for a time series UUID.
    SQLite.createindex!(
        store.db,
        METADATA_TABLE_NAME,
        "by_c_n_tst_features",
        ["owner_uuid", "name", "time_series_type", "features"];
        unique = true,
    )
    SQLite.createindex!(
        store.db,
        METADATA_TABLE_NAME,
        "by_ts_uuid",
        "time_series_uuid";
        unique = false,
    )
    return
end

function Base.deepcopy_internal(store::TimeSeriesMetadataStore, dict::IdDict)
    if haskey(dict, store)
        return dict[store]
    end

    new_db = SQLite.DB()
    backup(new_db, store.db)
    new_store = TimeSeriesMetadataStore(new_db)
    dict[store] = new_store
    return new_store
end

"""
Add metadata to the store. The caller must check if there are duplicates.
"""
function add_metadata!(
    store::TimeSeriesMetadataStore,
    owner::TimeSeriesOwners,
    metadata::TimeSeriesMetadata,
)
    TimerOutputs.@timeit SYSTEM_TIMERS "add ts metadata single" begin
        owner_category = _get_owner_category(owner)
        ts_type = time_series_metadata_to_data(metadata)
        ts_category = _get_time_series_category(ts_type)
        features = _make_features_string(metadata.features)
        vals = _create_row(
            metadata,
            owner,
            owner_category,
            string(nameof(ts_type)),
            ts_category,
            features,
        )
        params = repeat("?,", length(vals) - 1) * "jsonb(?)"
        SQLite.DBInterface.execute(
            store.db,
            "INSERT INTO $METADATA_TABLE_NAME VALUES($params)",
            vals,
        )
        @debug "Added metadata = $metadata to $(summary(owner))" _group =
            LOG_GROUP_TIME_SERIES
    end
    return
end

function add_metadata!(
    store::TimeSeriesMetadataStore,
    owners::Vector{<:TimeSeriesOwners},
    all_metadata::Vector{<:TimeSeriesMetadata},
)
    TimerOutputs.@timeit SYSTEM_TIMERS "add ts metadata bulk" begin
        @assert_op length(owners) == length(all_metadata)
        columns = (
            "id",
            "time_series_uuid",
            "time_series_type",
            "time_series_category",
            "initial_timestamp",
            "resolution_ms",
            "horizon_ms",
            "interval_ms",
            "window_count",
            "length",
            "name",
            "owner_uuid",
            "owner_type",
            "owner_category",
            "features",
            "metadata",
        )
        num_rows = length(all_metadata)
        num_columns = length(columns)
        data = OrderedDict(x => Vector{Any}(undef, num_rows) for x in columns)
        for i in 1:num_rows
            owner = owners[i]
            metadata = all_metadata[i]
            owner_category = _get_owner_category(owner)
            ts_type = time_series_metadata_to_data(metadata)
            ts_category = _get_time_series_category(ts_type)
            features = _make_features_string(metadata.features)
            row = _create_row(
                metadata,
                owner,
                owner_category,
                string(nameof(ts_type)),
                ts_category,
                features,
            )
            for (j, column) in enumerate(columns)
                data[column][i] = row[j]
            end
        end

        params = chop(repeat("?,", num_columns))
        SQLite.DBInterface.executemany(
            store.db,
            "INSERT INTO $METADATA_TABLE_NAME VALUES($params)",
            NamedTuple(Symbol(k) => v for (k, v) in data),
        )
        @debug "Added $num_rows instances of time series metadata" _group =
            LOG_GROUP_TIME_SERIES
        return
    end
end

"""
Backup the database to a file on the temporary filesystem and return that filename.
"""
function backup_to_temp(store::TimeSeriesMetadataStore)
    filename, io = mktemp()
    close(io)
    dst = SQLite.DB(filename)
    backup(dst, store.db)
    close(dst)
    return filename
end

"""
Clear all time series metadata from the store.
"""
function clear_metadata!(store::TimeSeriesMetadataStore)
    _execute(store, "DELETE FROM $METADATA_TABLE_NAME")
end

function check_params_compatibility(
    store::TimeSeriesMetadataStore,
    metadata::ForecastMetadata,
)
    params = ForecastParameters(;
        count = get_count(metadata),
        horizon = get_horizon(metadata),
        initial_timestamp = get_initial_timestamp(metadata),
        interval = get_interval(metadata),
        resolution = get_resolution(metadata),
    )
    check_params_compatibility(store, params)
    return
end

check_params_compatibility(
    store::TimeSeriesMetadataStore,
    metadata::StaticTimeSeriesMetadata,
) = nothing
check_params_compatibility(
    store::TimeSeriesMetadataStore,
    params::StaticTimeSeriesParameters,
) = nothing

function check_params_compatibility(
    store::TimeSeriesMetadataStore,
    params::ForecastParameters,
)
    store_params = get_forecast_parameters(store)
    isnothing(store_params) && return
    check_params_compatibility(store_params, params)
    return
end

# These are guaranteed to be consistent already.
check_consistency(::TimeSeriesMetadataStore, ::Type{<:Forecast}) = nothing

"""
Throw InvalidValue if the SingleTimeSeries arrays have different initial times or lengths.
Return the initial timestamp and length as a tuple.
"""
function check_consistency(store::TimeSeriesMetadataStore, ::Type{SingleTimeSeries})
    query = """
        SELECT
            DISTINCT initial_timestamp
            ,length
        FROM $METADATA_TABLE_NAME
        WHERE time_series_type = 'SingleTimeSeries'
    """
    table = Tables.rowtable(_execute(store, query))
    len = length(table)
    if len == 0
        return Dates.DateTime(Dates.Minute(0)), 0
    elseif len > 1
        throw(
            InvalidValue(
                "There are more than one sets of SingleTimeSeries initial times and lengths: $table",
            ),
        )
    end

    row = table[1]
    return Dates.DateTime(row.initial_timestamp), row.length
end

# check_consistency is not implemented on StaticTimeSeries because new types may have
# different requirments than SingleTimeSeries. Let future developers make that decision.

function get_forecast_initial_times(store::TimeSeriesMetadataStore)
    params = get_forecast_parameters(store)
    isnothing(params) && return []
    return get_initial_times(params.initial_timestamp, params.count, params.interval)
end

function get_forecast_parameters(store::TimeSeriesMetadataStore)
    query = """
        SELECT
            horizon_ms
            ,initial_timestamp
            ,interval_ms
            ,resolution_ms
            ,window_count
        FROM $METADATA_TABLE_NAME
        WHERE horizon_ms IS NOT NULL
        LIMIT 1
        """
    table = Tables.rowtable(_execute(store, query))
    isempty(table) && return nothing
    row = table[1]
    return ForecastParameters(;
        horizon = row.horizon_ms,
        initial_timestamp = Dates.DateTime(row.initial_timestamp),
        interval = Dates.Millisecond(row.interval_ms),
        count = row.window_count,
        resolution = Dates.Millisecond(row.resolution_ms),
    )
end

function get_forecast_window_count(store::TimeSeriesMetadataStore)
    query = """
        SELECT
            window_count
        FROM $METADATA_TABLE_NAME
        WHERE window_count IS NOT NULL
        LIMIT 1
        """
    table = Tables.rowtable(_execute(store, query))
    return isempty(table) ? nothing : table[1].window_count
end

function get_forecast_horizon(store::TimeSeriesMetadataStore)
    query = """
        SELECT
            horizon_ms
        FROM $METADATA_TABLE_NAME
        WHERE horizon_ms IS NOT NULL
        LIMIT 1
        """
    table = Tables.rowtable(_execute(store, query))
    return isempty(table) ? nothing : Dates.Millisecond(table[1].horizon_ms)
end

function get_forecast_initial_timestamp(store::TimeSeriesMetadataStore)
    query = """
        SELECT
            initial_timestamp
        FROM $METADATA_TABLE_NAME
        WHERE horizon_ms IS NOT NULL
        LIMIT 1
        """
    table = Tables.rowtable(_execute(store, query))
    return if isempty(table)
        nothing
    else
        Dates.DateTime(table[1].initial_timestamp)
    end
end

function get_forecast_interval(store::TimeSeriesMetadataStore)
    query = """
        SELECT
            interval_ms
        FROM $METADATA_TABLE_NAME
        WHERE interval_ms IS NOT NULL
        LIMIT 1
        """
    table = Tables.rowtable(_execute(store, query))
    return if isempty(table)
        nothing
    else
        Dates.Millisecond(table[1].interval_ms)
    end
end

"""
Return the metadata matching the inputs. Throw an exception if there is more than one
matching input.
"""
function get_metadata(
    store::TimeSeriesMetadataStore,
    owner::TimeSeriesOwners,
    time_series_type::Type{<:TimeSeriesData},
    name::String;
    features...,
)
    metadata = _try_get_time_series_metadata_by_full_params(
        store,
        owner,
        time_series_type,
        name;
        features...,
    )
    !isnothing(metadata) && return metadata

    metadata_items = list_metadata(
        store,
        owner;
        time_series_type = time_series_type,
        name = name,
        features...,
    )
    len = length(metadata_items)
    if len == 0
        if time_series_type === Deterministic
            # This is a hack to account for the fact that we allow users to use
            # Deterministic interchangeably with DeterministicSingleTimeSeries.
            try
                return get_metadata(
                    store,
                    owner,
                    DeterministicSingleTimeSeries,
                    name;
                    features...,
                )
            catch _
                throw(
                    ArgumentError(
                        "No matching metadata is stored. " *
                        "Tried $time_series_type and DeterministicSingleTimeSeries.",
                    ),
                )
            end
        end
        throw(ArgumentError("No matching metadata is stored."))
    elseif len > 1
        throw(ArgumentError("Found more than one matching metadata: $len"))
    end

    return metadata_items[1]
end

"""
Return the number of unique time series arrays.
"""
function get_num_time_series(store::TimeSeriesMetadataStore)
    return Tables.rowtable(
        _execute(
            store,
            "SELECT COUNT(DISTINCT time_series_uuid) AS count FROM $METADATA_TABLE_NAME",
        ),
    )[1].count
end

"""
Return an instance of TimeSeriesCounts.
"""
function get_time_series_counts(store::TimeSeriesMetadataStore)
    query_components = """
        SELECT
            COUNT(DISTINCT owner_uuid) AS count
        FROM $METADATA_TABLE_NAME
        WHERE owner_category = 'Component'
    """
    query_attributes = """
        SELECT
            COUNT(DISTINCT owner_uuid) AS count
        FROM $METADATA_TABLE_NAME
        WHERE owner_category = 'SupplementalAttribute'
    """
    query_sts = """
        SELECT
            COUNT(DISTINCT time_series_uuid) AS count
        FROM $METADATA_TABLE_NAME
        WHERE interval_ms IS NULL
    """
    query_forecasts = """
        SELECT
            COUNT(DISTINCT time_series_uuid) AS count
        FROM $METADATA_TABLE_NAME
        WHERE interval_ms IS NOT NULL
    """

    count_components = _execute_count(store, query_components)
    count_attributes = _execute_count(store, query_attributes)
    count_sts = _execute_count(store, query_sts)
    count_forecasts = _execute_count(store, query_forecasts)

    return TimeSeriesCounts(;
        components_with_time_series = count_components,
        supplemental_attributes_with_time_series = count_attributes,
        static_time_series_count = count_sts,
        forecast_count = count_forecasts,
    )
end

"""
Return a Vector of OrderedDict of stored time series counts by type.
"""
function get_time_series_counts_by_type(store::TimeSeriesMetadataStore)
    query = """
        SELECT
            time_series_type
            ,count(*) AS count
        FROM $METADATA_TABLE_NAME
        GROUP BY
            time_series_type
        ORDER BY
            time_series_type
    """
    table = Tables.rowtable(_execute(store, query))
    return [
        OrderedDict("type" => x.time_series_type, "count" => x.count) for x in table
    ]
end

"""
Return a DataFrame with the number of time series by type for components and supplemental
attributes.
"""
function get_time_series_summary_table(store::TimeSeriesMetadataStore)
    query = """
        SELECT
            owner_type
            ,owner_category
            ,time_series_type
            ,time_series_category
            ,initial_timestamp
            ,resolution_ms
            ,count(*) AS count
        FROM $METADATA_TABLE_NAME
        GROUP BY
            owner_type
            ,owner_category
            ,time_series_type
            ,initial_timestamp
            ,resolution_ms
        ORDER BY
            owner_category
            ,owner_type
            ,time_series_type
            ,initial_timestamp
            ,resolution_ms
    """
    return DataFrame(_execute(store, query))
end

"""
Return True if there is time series metadata matching the inputs.
"""
function has_metadata(
    store::TimeSeriesMetadataStore,
    owner::TimeSeriesOwners,
    metadata::TimeSeriesMetadata,
)
    features = Dict(Symbol(k) => v for (k, v) in get_features(metadata))
    return _try_has_time_series_metadata_by_full_params(
        store,
        owner,
        time_series_metadata_to_data(metadata),
        get_name(metadata);
        features...,
    )
end

function has_metadata(
    store::TimeSeriesMetadataStore,
    owner::TimeSeriesOwners,
    time_series_type::Type{<:TimeSeriesData},
    name::String;
    features...,
)
    if _try_has_time_series_metadata_by_full_params(
        store,
        owner,
        time_series_type,
        name;
        features...,
    )
        return true
    end

    where_clause, params = _make_where_clause(
        owner;
        time_series_type = time_series_type,
        name = name,
        features...,
    )
    query = "SELECT COUNT(*) AS count FROM $METADATA_TABLE_NAME $where_clause"
    return _execute_count(store, query, params) > 0
end

"""
Return True if there is time series matching the UUID.
"""
function has_time_series(store::TimeSeriesMetadataStore, time_series_uuid::Base.UUID)
    where_clause = "WHERE time_series_uuid = ?"
    params = [string(time_series_uuid)]
    return _has_time_series(store, where_clause, params)
end

function has_time_series(
    store::TimeSeriesMetadataStore,
    owner::TimeSeriesOwners,
)
    where_clause = "WHERE owner_uuid = ?"
    params = [string(get_uuid(owner))]
    return _has_time_series(store, where_clause, params)
end

function has_time_series(
    store::TimeSeriesMetadataStore,
    owner::TimeSeriesOwners,
    time_series_type::Type{<:TimeSeriesData},
)
    where_clause, params = _make_where_clause(owner; time_series_type = time_series_type)
    return _has_time_series(store, where_clause, params)
end

has_time_series(
    store::TimeSeriesMetadataStore,
    owner::TimeSeriesOwners,
    time_series_type::Type{<:TimeSeriesData},
    name::String;
    features...,
) = has_metadata(store, owner, time_series_type, name; features...)

"""
Return a sorted Vector of distinct resolutions for all time series of the given type
(or all types).
"""
function get_time_series_resolutions(
    store::TimeSeriesMetadataStore;
    time_series_type::Union{Type{<:TimeSeriesData}, Nothing} = nothing,
)
    params = []
    if isnothing(time_series_type)
        where_clause = ""
    else
        where_clause = "WHERE time_series_type = ?"
        push!(params, string(nameof(time_series_type)))
    end
    query = """
        SELECT
            DISTINCT resolution_ms
        FROM $METADATA_TABLE_NAME $where_clause
        ORDER BY resolution_ms
    """
    return Dates.Millisecond.(
        Tables.columntable(_execute(store, query, params)).resolution_ms
    )
end

"""
Return the time series UUIDs that match the inputs.
"""
function list_matching_time_series_uuids(
    store::TimeSeriesMetadataStore;
    time_series_type::Union{Type{<:TimeSeriesData}, Nothing} = nothing,
    name::Union{String, Nothing} = nothing,
    features...,
)
    where_clause, params = _make_where_clause(;
        time_series_type = time_series_type,
        name = name,
        features...,
    )
    query = "SELECT DISTINCT time_series_uuid FROM $METADATA_TABLE_NAME $where_clause"
    table = Tables.columntable(_execute(store, query, params))
    return Base.UUID.(table.time_series_uuid)
end

function list_metadata(
    store::TimeSeriesMetadataStore,
    owner::TimeSeriesOwners;
    time_series_type::Union{Type{<:TimeSeriesData}, Nothing} = nothing,
    name::Union{String, Nothing} = nothing,
    features...,
)
    where_clause, params = _make_where_clause(
        owner;
        time_series_type = time_series_type,
        name = name,
        features...,
    )
    query = """
        SELECT json(metadata) AS metadata
        FROM $METADATA_TABLE_NAME
        $where_clause
    """
    table = Tables.rowtable(_execute(store, query, params))
    return [_deserialize_metadata(x.metadata) for x in table]
end

"""
Return a Vector of NamedTuple of owner UUID and time series metadata matching the inputs. 
"""
function list_metadata_with_owner_uuid(
    store::TimeSeriesMetadataStore,
    owner_type::Type{<:TimeSeriesOwners};
    time_series_type::Union{Type{<:TimeSeriesData}, Nothing} = nothing,
    name::Union{String, Nothing} = nothing,
    features...,
)
    where_clause, params = _make_where_clause(
        owner_type;
        time_series_type = time_series_type,
        name = name,
        features...,
    )
    query = """
        SELECT owner_uuid, json(metadata) AS metadata
        FROM $METADATA_TABLE_NAME
        $where_clause
    """
    table = Tables.rowtable(_execute(store, query, params))
    return [
        (
            owner_uuid = Base.UUID(x.owner_uuid),
            metadata = _deserialize_metadata(x.metadata),
        ) for x in table
    ]
end

function list_owner_uuids_with_time_series(
    store::TimeSeriesMetadataStore,
    owner_type::Type{<:TimeSeriesOwners};
    time_series_type::Union{Nothing, Type{<:TimeSeriesData}} = nothing,
)
    category = _get_owner_category(owner_type)
    vals = ["owner_category = ?"]
    params = [category]
    if !isnothing(time_series_type)
        push!(vals, "time_series_type = ?")
        push!(params, string(nameof(time_series_type)))
    end

    where_clause = join(vals, " AND ")
    query = """
        SELECT
            DISTINCT owner_uuid
        FROM $METADATA_TABLE_NAME
        WHERE $where_clause
    """
    return Base.UUID.(Tables.columntable(_execute(store, query, params)).owner_uuid)
end

"""
Return information about each time series array attached to the owner.
This information can be used to call get_time_series.
"""
function get_time_series_keys(store::TimeSeriesMetadataStore, owner::TimeSeriesOwners)
    return [make_time_series_key(x) for x in list_metadata(store, owner)]
end

"""
Remove the matching metadata from the store.
"""
function remove_metadata!(
    store::TimeSeriesMetadataStore,
    owner::TimeSeriesOwners,
    metadata::TimeSeriesMetadata,
)
    where_clause, params = _make_where_clause(owner, metadata)
    num_deleted = _remove_metadata!(store, where_clause, params)
    if num_deleted != 1
        error("Bug: unexpected number of deletions: $num_deleted. Should have been 1.")
    end
end

function remove_metadata!(
    store::TimeSeriesMetadataStore,
    owner::TimeSeriesOwners;
    time_series_type::Union{Type{<:TimeSeriesData}, Nothing} = nothing,
    name::Union{String, Nothing} = nothing,
    features...,
)
    where_clause, params = _make_where_clause(
        owner;
        time_series_type = time_series_type,
        name = name,
        # TODO/PERF: This can be made faster by attempting search by a full match
        # and then fallback to partial. We likely don't care about this for removing.
        require_full_feature_match = false,
        features...,
    )
    num_deleted = _remove_metadata!(store, where_clause, params)
    if num_deleted == 0
        if time_series_type === Deterministic
            # This is a hack to account for the fact that we allow users to use
            # Deterministic interchangeably with DeterministicSingleTimeSeries.
            remove_metadata!(
                store,
                owner;
                time_series_type = DeterministicSingleTimeSeries,
                name = name,
                features...,
            )
        else
            @warn "No time series metadata was deleted."
        end
    end
end

function replace_component_uuid!(
    store::TimeSeriesMetadataStore,
    old_uuid::Base.UUID,
    new_uuid::Base.UUID,
)
    query = """
        UPDATE $METADATA_TABLE_NAME
        SET owner_uuid = ?
        WHERE owner_uuid = ?
    """
    params = [string(new_uuid), string(old_uuid)]
    _execute(store, query, params)
    return
end

"""
Run a query and return the results in a DataFrame.
"""
function sql(store::TimeSeriesMetadataStore, query::String, params = nothing)
    return DataFrames.DataFrame(_execute(store, query, params))
end

function to_h5_file(store::TimeSeriesMetadataStore, dst::String)
    metadata_path = backup_to_temp(store)
    data = open(metadata_path, "r") do io
        read(io)
    end

    HDF5.h5open(dst, "r+") do file
        if HDF5_TS_METADATA_ROOT_PATH in keys(file)
            HDF5.delete_object(file, HDF5_TS_METADATA_ROOT_PATH)
        end
        file[HDF5_TS_METADATA_ROOT_PATH] = data
    end

    return
end

function _create_row(
    metadata::ForecastMetadata,
    owner,
    owner_category,
    ts_type,
    ts_category,
    features,
)
    return (
        missing,  # auto-assigned by sqlite
        string(get_time_series_uuid(metadata)),
        ts_type,
        ts_category,
        string(get_initial_timestamp(metadata)),
        Dates.Millisecond(get_resolution(metadata)).value,
        Dates.Millisecond(get_horizon(metadata)),
        Dates.Millisecond(get_interval(metadata)).value,
        get_count(metadata),
        missing,
        get_name(metadata),
        string(get_uuid(owner)),
        string(nameof(typeof(owner))),
        owner_category,
        features,
        JSON3.write(serialize(metadata)),
    )
end

function _create_row(
    metadata::StaticTimeSeriesMetadata,
    owner,
    owner_category,
    ts_type,
    ts_category,
    features,
)
    return (
        missing,  # auto-assigned by sqlite
        string(get_time_series_uuid(metadata)),
        ts_type,
        ts_category,
        string(get_initial_timestamp(metadata)),
        Dates.Millisecond(get_resolution(metadata)).value,
        missing,
        missing,
        missing,
        get_length(metadata),
        get_name(metadata),
        string(get_uuid(owner)),
        string(nameof(typeof(owner))),
        owner_category,
        features,
        JSON3.write(serialize(metadata)),
    )
end

_execute(s::TimeSeriesMetadataStore, q, p = nothing) =
    execute(s.db, q, p, LOG_GROUP_TIME_SERIES)
_execute_count(s::TimeSeriesMetadataStore, q, p = nothing) =
    execute_count(s.db, q, p, LOG_GROUP_TIME_SERIES)

function _has_time_series(store::TimeSeriesMetadataStore, where_clause::String, params)
    query = "SELECT COUNT(*) AS count FROM $METADATA_TABLE_NAME $where_clause"
    return _execute_count(store, query, params) > 0
end

function _remove_metadata!(
    store::TimeSeriesMetadataStore,
    where_clause::AbstractString,
    params,
)
    _execute(store, "DELETE FROM $METADATA_TABLE_NAME $where_clause", params)
    table = Tables.rowtable(_execute(store, "SELECT CHANGES() AS changes"))
    @assert_op length(table) == 1
    @debug "Deleted $(table[1].changes) rows from the time series metadata table" _group =
        LOG_GROUP_TIME_SERIES
    return table[1].changes
end

function _try_get_time_series_metadata_by_full_params(
    store::TimeSeriesMetadataStore,
    owner::TimeSeriesOwners,
    time_series_type::Type{<:TimeSeriesData},
    name::String;
    features...,
)
    rows = _try_time_series_metadata_by_full_params(
        store,
        owner,
        time_series_type,
        name,
        "json(metadata) AS metadata";
        features...,
    )
    len = length(rows)
    if len == 0
        return nothing
    elseif len == 1
        return _deserialize_metadata(rows[1].metadata)
    else
        throw(ArgumentError("Found more than one matching time series: $len"))
    end
end

function _try_has_time_series_metadata_by_full_params(
    store::TimeSeriesMetadataStore,
    owner::TimeSeriesOwners,
    time_series_type::Type{<:TimeSeriesData},
    name::String;
    features...,
)
    row = _try_time_series_metadata_by_full_params(
        store,
        owner,
        time_series_type,
        name,
        "id";
        features...,
    )
    return !isempty(row)
end

function _try_time_series_metadata_by_full_params(
    store::TimeSeriesMetadataStore,
    owner::TimeSeriesOwners,
    time_series_type::Type{<:TimeSeriesData},
    name::String,
    column::String;
    features...,
)
    where_clause, params = _make_where_clause(
        owner;
        time_series_type = time_series_type,
        name = name,
        require_full_feature_match = true,
        features...,
    )
    query = "SELECT $column FROM $METADATA_TABLE_NAME $where_clause"
    return Tables.rowtable(_execute(store, query, params))
end

function compare_values(
    x::TimeSeriesMetadataStore,
    y::TimeSeriesMetadataStore;
    compare_uuids = false,
    exclude = Set{Symbol}(),
)
    # Note that we can't compare missing values.
    owner_uuid = compare_uuids ? ", owner_uuid" : ""
    query = """
        SELECT id, metadata, time_series_uuid $owner_uuid
        FROM $METADATA_TABLE_NAME ORDER BY id
    """
    table_x = Tables.rowtable(_execute(x, query))
    table_y = Tables.rowtable(_execute(y, query))
    return table_x == table_y
end

### Non-TimeSeriesMetadataStore functions ###

_convert_ts_type_to_string(ts_type::Type{<:TimeSeriesData}) = string(nameof(ts_type))

function _deserialize_metadata(text::String)
    val = JSON3.read(text, Dict)
    return deserialize(get_type_from_serialization_data(val), val)
end

_get_owner_category(
    ::Union{InfrastructureSystemsComponent, Type{<:InfrastructureSystemsComponent}},
) = "Component"
_get_owner_category(::Union{SupplementalAttribute, Type{<:SupplementalAttribute}}) =
    "SupplementalAttribute"
_get_time_series_category(::Type{<:Forecast}) = "Forecast"
_get_time_series_category(::Type{<:StaticTimeSeries}) = "StaticTimeSeries"

function _make_feature_filter!(params; features...)
    data = _make_sorted_feature_array(; features...)
    strings = []
    for (key, val) in data
        push!(strings, "metadata->>'\$.features.$key' = ?")
        push!(params, val)
    end
    return join(strings, " AND ")
end

_make_val_str(val::Union{Bool, Int}) = string(val)
_make_val_str(val::String) = "'$val'"

function _make_features_string(features::Dict{String, Union{Bool, Int, String}})
    key_names = sort!(collect(keys(features)))
    data = [Dict(k => features[k]) for k in key_names]
    return JSON3.write(data)
end

function _make_features_string(; features...)
    key_names = sort!(collect(string.(keys(features))))
    data = [Dict(k => features[Symbol(k)]) for (k) in key_names]
    return JSON3.write(data)
end

function _make_sorted_feature_array(; features...)
    key_names = sort!(collect(string.(keys(features))))
    return [(key, features[Symbol(key)]) for key in key_names]
end

function _make_where_clause(
    owner_type::Type{<:TimeSeriesOwners};
    time_series_type::Union{Type{<:TimeSeriesData}, Nothing} = nothing,
    name::Union{String, Nothing} = nothing,
    require_full_feature_match = false,
    features...,
)
    params = [_get_owner_category(owner_type)]
    return _make_where_clause(;
        owner_clause = "owner_category = ?",
        time_series_type = time_series_type,
        name = name,
        require_full_feature_match = require_full_feature_match,
        params = params,
        features...,
    )
end

function _make_where_clause(
    owner::TimeSeriesOwners;
    time_series_type::Union{Type{<:TimeSeriesData}, Nothing} = nothing,
    name::Union{String, Nothing} = nothing,
    require_full_feature_match = false,
    params = nothing,
    features...,
)
    if isnothing(params)
        params = []
    end
    push!(params, string(get_uuid(owner)))
    return _make_where_clause(;
        owner_clause = "owner_uuid = ?",
        time_series_type = time_series_type,
        name = name,
        require_full_feature_match = require_full_feature_match,
        params = params,
        features...,
    )
end

function _make_where_clause(;
    owner_clause::Union{String, Nothing} = nothing,
    time_series_type::Union{Type{<:TimeSeriesData}, Nothing} = nothing,
    name::Union{String, Nothing} = nothing,
    require_full_feature_match = false,
    params = nothing,
    features...,
)
    if isnothing(params)
        params = []
    end
    vals = String[]
    if !isnothing(owner_clause)
        push!(vals, owner_clause)
    end
    if !isnothing(name)
        push!(vals, "name = ?")
        push!(params, name)
    end
    if !isnothing(time_series_type)
        push!(vals, "time_series_type = ?")
        push!(params, _convert_ts_type_to_string(time_series_type))
    end
    if !isempty(features)
        if require_full_feature_match
            val = "features = ?"
            push!(params, _make_features_string(; features...))
        else
            val = "$(_make_feature_filter!(params; features...))"
        end
        push!(vals, val)
    end

    return (isempty(vals) ? "" : "WHERE (" * join(vals, " AND ") * ")", params)
end

function _make_where_clause(owner::TimeSeriesOwners, metadata::TimeSeriesMetadata)
    features = Dict(Symbol(k) => v for (k, v) in get_features(metadata))
    return _make_where_clause(
        owner;
        time_series_type = time_series_metadata_to_data(metadata),
        name = get_name(metadata),
        features...,
    )
end
