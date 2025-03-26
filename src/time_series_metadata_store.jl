const ASSOCIATIONS_TABLE_NAME = "time_series_associations"
const METADATA_TABLE_NAME = "time_series_metadata"
const DB_FILENAME = "time_series_metadata.db"

@kwdef struct HasMetadataQueryKey
    has_name::Bool
    num_possible_types::Int
    has_resolution::Bool
    has_features::Bool
    feature_filter::Union{Nothing, String} = nothing
end

mutable struct TimeSeriesMetadataStore
    db::SQLite.DB
    # Caching compiled SQL statements saves 3-4 us per query query.
    # DBInterface.jl does something similar with @prepare.
    # We need this to be tied to our connection.
    cached_statements::Dict{String, SQLite.Stmt}
    # This caching allows the code to skip some string interpolations.
    # It is experimental for PowerSimulations, which calls has_metadata frequently.
    # It may not be necessary. Savings are minimal.
    has_metadata_statements::Dict{HasMetadataQueryKey, SQLite.Stmt}
    metadata_uuids::Dict{Base.UUID, TimeSeriesMetadata}
    # If you add any fields, ensure they are managed in deepcopy_internal below.
end

"""
Construct a new TimeSeriesMetadataStore with an in-memory database.
"""
function TimeSeriesMetadataStore()
    # This metadata is not expected to exceed system memory, so create an in-memory
    # database so that it is faster. This could be changed.
    store = TimeSeriesMetadataStore(
        SQLite.DB(),
        Dict{String, SQLite.Stmt}(),
        Dict{HasMetadataQueryKey, SQLite.Stmt}(),
        Dict{Base.UUID, TimeSeriesMetadata}(),
    )
    _create_associations_table!(store)
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
    store = TimeSeriesMetadataStore(
        db,
        Dict{Base.UUID, TimeSeriesMetadata}(),
        Dict{Tuple{Bool, Bool, Int64, String}, SQLite.Stmt}(),
        Dict{Base.UUID, TimeSeriesMetadata}(),
    )
    if _needs_migration(store.db)
        _migrate_legacy_schema(store)
    end

    _apply_horizon_type_fix_if_needed(store.db)
    _load_metadata_into_memory!(store)
    _create_indexes!(store)
    @debug "Loaded time series metadata from file" _group = LOG_GROUP_TIME_SERIES filename
    return store
end

function _load_metadata_into_memory!(store::TimeSeriesMetadataStore)
    stmt =
        SQLite.Stmt(store.db, "SELECT json(metadata) AS metadata FROM $METADATA_TABLE_NAME")
    for metadata_as_str in Tables.columntable(SQLite.DBInterface.execute(stmt)).metadata
        metadata = _deserialize_metadata(metadata_as_str)
        uuid = get_uuid(metadata)
        if haskey(store.metadata_uuids, uuid)
            error("Bug: duplicate metadata UUID $(uuid)")
        end
        store.metadata_uuids[uuid] = metadata
    end

    # There is no need to keep this table around.
    # We will create it again if the system is serialized.
    SQLite.DBInterface.execute(store.db, "DROP TABLE $METADATA_TABLE_NAME")
end

function _list_columns(db::SQLite.DB, table_name::String)
    return Tables.columntable(
        SQLite.DBInterface.execute(
            db,
            "SELECT name FROM pragma_table_info('$table_name')",
        ),
    )[1]
end

function _needs_migration(db::SQLite.DB)
    return "time_series_uuid" in _list_columns(db, METADATA_TABLE_NAME)
end

function _apply_horizon_type_fix_if_needed(db::SQLite.DB)
    # Version <= 2.4.1 had a bug where horizon_ms was mistakenly written to the db
    # as a Serialization.serialize(Dates.Millisecond) instead of an integer.
    # This function can be removed in in 4.0 when we no longer support deserializing
    # systems from 2.x.
    partial_query = """
        SELECT horizon_ms
        FROM time_series_associations
        WHERE horizon_ms IS NOT NULL
        LIMIT 1
    """
    vals = Tables.columntable(SQLite.DBInterface.execute(db, partial_query)).horizon_ms
    if !isempty(vals) && vals[1] isa Dates.Period
        query = """
            SELECT id, horizon_ms
            FROM $ASSOCIATIONS_TABLE_NAME
            WHERE horizon_ms IS NOT NULL
        """
        update_query = "UPDATE $ASSOCIATIONS_TABLE_NAME SET horizon_ms = ? WHERE id = ?"
        stmt = SQLite.Stmt(db, update_query)
        SQLite.transaction(db) do
            for row in Tables.rowtable(SQLite.DBInterface.execute(db, query))
                if row.horizon_ms isa Dates.Period
                    params = (row.horizon_ms.value, row.id)
                    SQLite.DBInterface.execute(stmt, params)
                end
            end
        end
    end
end

function _migrate_legacy_schema(store::TimeSeriesMetadataStore)
    # The original schema had one table where the metadata column was a JSON string.
    # The new schema has two tables where the metadata is split out into a separate table.
    # There was a previously-inconsequential bug where DeterministicSingleTimeSeries
    # metadata had the same UUID as its shared SingleTimeSeries metadata. 
    # Those need new UUIDs to make the new schema work.
    @info "Start migration of time series metadata to new schema."
    for index in ("by_c_n_tst_features", "by_ts_uuid")
        SQLite.DBInterface.execute(store.db, "DROP INDEX IF EXISTS $index")
    end
    new_associations = Tuple[]
    metadata_rows = Tuple[]
    unique_metadata = Dict{String, String}()
    for row in Tables.rowtable(
        SQLite.DBInterface.execute(
            store.db,
            """
                SELECT
                    id
                    ,time_series_uuid
                    ,time_series_type
                    ,time_series_category
                    ,initial_timestamp
                    ,resolution_ms
                    ,horizon_ms
                    ,interval_ms
                    ,window_count
                    ,length
                    ,name
                    ,owner_uuid
                    ,owner_type
                    ,owner_category
                    ,features
                    ,json(metadata) as metadata
                FROM $METADATA_TABLE_NAME
            """),
    )
        metadata = _deserialize_metadata(row.metadata)
        if occursin("DeterministicSingleTimeSeries", row.metadata)
            assign_new_uuid_internal!(metadata)
        end
        metadata_uuid = string(get_uuid(metadata))
        if haskey(unique_metadata, metadata_uuid)
            if row.metadata != unique_metadata[metadata_uuid]
                error(
                    "Bug: Unexpected mismatch in metadata JSON text: " *
                    "first = $(row.metadata) second = $(unique_metadata[metadata_uuid])",
                )
            end
        else
            unique_metadata[metadata_uuid] = row.metadata
            push!(metadata_rows, (missing, metadata_uuid, row.metadata))
        end
        vals = values(row)
        new_row = (vals[1:(end - 1)]..., metadata_uuid)
        push!(new_associations, new_row)
    end
    _create_associations_table!(store)
    _add_rows!(
        store,
        new_associations,
        (
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
            "metadata_uuid",
        ),
        ASSOCIATIONS_TABLE_NAME,
    )
    SQLite.DBInterface.execute(store.db, "DROP TABLE $METADATA_TABLE_NAME")
    _create_metadata_table!(store.db)
    _add_rows!(
        store,
        metadata_rows,
        (
            "id",
            "metadata_uuid",
            "metadata",
        ),
        METADATA_TABLE_NAME,
    )
    @info "Migrated time series metadata to updated schema."
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

function _create_associations_table!(store::TimeSeriesMetadataStore)
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
        "metadata_uuid TEXT NOT NULL",
    ]
    schema_text = join(schema, ",")
    SQLite.DBInterface.execute(
        store.db,
        "CREATE TABLE $(ASSOCIATIONS_TABLE_NAME)($(schema_text))",
    )
    @debug "Created time series associations table" schema _group = LOG_GROUP_TIME_SERIES
    return
end

function _create_metadata_table!(db::SQLite.DB)
    schema = [
        "id INTEGER PRIMARY KEY",
        "metadata_uuid TEXT NOT NULL",
        "metadata JSON NOT NULL",
    ]
    schema_text = join(schema, ",")
    SQLite.DBInterface.execute(
        db,
        "CREATE TABLE $(METADATA_TABLE_NAME)($(schema_text))",
    )
    @debug "Created time series metadata table" schema _group = LOG_GROUP_TIME_SERIES
    return
end

function _create_indexes!(store::TimeSeriesMetadataStore)
    # Index strategy:
    # 1. Optimize for these user queries with indexes:
    #    1a. all time series attached to one component/attribute
    #    1b. time series for one component/attribute + name + type + resolution
    #    1c. time series for one component/attribute with all features
    # 2. Optimize for checks at system.add_time_series. Use all fields and features.
    # 3. Optimize for returning all metadata for a time series UUID.
    # resolution_ms was added in v2.4.4.
    if "by_c_n_tst_features" in
       SQLite.indices(store.db).name && !(
        "resolution_ms" in
        sql(store, "PRAGMA index_info('by_c_n_tst_features')")[!, "name"]
    )
        SQLite.dropindex!(store.db, "by_c_n_tst_features"; ifexists = true)
    end
    SQLite.createindex!(
        store.db,
        ASSOCIATIONS_TABLE_NAME,
        "by_c_n_tst_features",
        ["owner_uuid", "time_series_type", "name", "resolution_ms", "features"];
        unique = true,
        ifnotexists = true,
    )
    SQLite.createindex!(
        store.db,
        ASSOCIATIONS_TABLE_NAME,
        "by_ts_uuid",
        "time_series_uuid";
        unique = false,
        ifnotexists = true,
    )
    return
end

function Base.deepcopy_internal(store::TimeSeriesMetadataStore, dict::IdDict)
    if haskey(dict, store)
        return dict[store]
    end

    new_db = SQLite.DB()
    backup(new_db, store.db)
    new_store = TimeSeriesMetadataStore(
        new_db,
        Dict{String, SQLite.Stmt}(),
        Dict{HasMetadataQueryKey, SQLite.Stmt}(),
        deepcopy(store.metadata_uuids),
    )
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
    owner_category = _get_owner_category(owner)
    time_series_type = time_series_metadata_to_data(metadata)
    ts_category = _get_time_series_category(time_series_type)
    features = make_features_string(metadata.features)
    vals = _create_row(
        metadata,
        owner,
        owner_category,
        _convert_ts_type_to_string(time_series_type),
        ts_category,
        features,
    )
    params = chop(repeat("?,", length(vals)))
    _execute_cached(
        store,
        "INSERT INTO $ASSOCIATIONS_TABLE_NAME VALUES($params)",
        vals,
    )
    metadata_uuid = get_uuid(metadata)
    if !haskey(store.metadata_uuids, metadata_uuid)
        store.metadata_uuids[metadata_uuid] = metadata
    end
    @debug "Added metadata = $metadata to $(summary(owner))" _group =
        LOG_GROUP_TIME_SERIES
    return
end

function _add_rows!(
    store::TimeSeriesMetadataStore,
    rows::Vector,
    columns,
    table_name::String,
)
    num_rows = length(rows)
    num_columns = length(columns)
    data = OrderedDict(x => Vector{Any}(undef, num_rows) for x in columns)
    for (i, row) in enumerate(rows)
        for (j, column) in enumerate(columns)
            data[column][i] = row[j]
        end
    end

    placeholder = chop(repeat("?,", num_columns))
    SQLite.DBInterface.executemany(
        store.db,
        "INSERT INTO $table_name VALUES($placeholder)",
        NamedTuple(Symbol(k) => v for (k, v) in data),
    )
    @debug "Added $num_rows rows to table = $table_name" _group = LOG_GROUP_TIME_SERIES
    return
end

"""
Backup the database to a file on the temporary filesystem and return that filename.
Serialize the metadata in JSON format to a metadata table.
"""
function backup_to_temp(store::TimeSeriesMetadataStore)
    filename, io = mktemp()
    close(io)
    dst = SQLite.DB(filename)
    backup(dst, store.db)
    _create_metadata_table!(dst)
    query = "INSERT INTO $METADATA_TABLE_NAME VALUES(?,?,jsonb(?))"
    SQLite.transaction(dst) do
        stmt = SQLite.Stmt(dst, query)
        for metadata in values(store.metadata_uuids)
            params = (missing, string(get_uuid(metadata)), JSON3.write(serialize(metadata)))
            SQLite.DBInterface.execute(stmt, params)
        end
    end
    close(dst)
    return filename
end

"""
Clear all time series metadata from the store.
"""
function clear_metadata!(store::TimeSeriesMetadataStore)
    _execute(store, "DELETE FROM $ASSOCIATIONS_TABLE_NAME")
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
        FROM $ASSOCIATIONS_TABLE_NAME
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

const _QUERY_GET_FORECAST_PARAMS = """
    SELECT
        horizon_ms
        ,initial_timestamp
        ,interval_ms
        ,resolution_ms
        ,window_count
    FROM $ASSOCIATIONS_TABLE_NAME
    WHERE horizon_ms IS NOT NULL
    LIMIT 1
"""
function get_forecast_parameters(store::TimeSeriesMetadataStore)
    table = Tables.rowtable(_execute_cached(store, _QUERY_GET_FORECAST_PARAMS))
    isempty(table) && return nothing
    row = table[1]
    return ForecastParameters(;
        horizon = Dates.Millisecond(row.horizon_ms),
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
        FROM $ASSOCIATIONS_TABLE_NAME
        WHERE window_count IS NOT NULL
        LIMIT 1
        """
    table = Tables.rowtable(_execute_cached(store, query))
    return isempty(table) ? nothing : table[1].window_count
end

function get_forecast_horizon(store::TimeSeriesMetadataStore)
    query = """
        SELECT
            horizon_ms
        FROM $ASSOCIATIONS_TABLE_NAME
        WHERE horizon_ms IS NOT NULL
        LIMIT 1
        """
    table = Tables.rowtable(_execute_cached(store, query))
    return isempty(table) ? nothing : Dates.Millisecond(table[1].horizon_ms)
end

function get_forecast_initial_timestamp(store::TimeSeriesMetadataStore)
    query = """
        SELECT
            initial_timestamp
        FROM $ASSOCIATIONS_TABLE_NAME
        WHERE horizon_ms IS NOT NULL
        LIMIT 1
        """
    table = Tables.rowtable(_execute_cached(store, query))
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
        FROM $ASSOCIATIONS_TABLE_NAME
        WHERE interval_ms IS NOT NULL
        LIMIT 1
        """
    table = Tables.rowtable(_execute_cached(store, query))
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
    resolution::Union{Nothing, Dates.Period} = nothing,
    features...,
)
    metadata = _try_get_time_series_metadata_by_full_params(
        store,
        owner,
        time_series_type,
        name;
        resolution = resolution,
        features...,
    )
    !isnothing(metadata) && return metadata

    metadata_items = list_metadata(
        store,
        owner;
        time_series_type = time_series_type,
        name = name,
        resolution = resolution,
        features...,
    )
    len = length(metadata_items)
    if len == 0
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
            "SELECT COUNT(DISTINCT time_series_uuid) AS count FROM $ASSOCIATIONS_TABLE_NAME",
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
        FROM $ASSOCIATIONS_TABLE_NAME
        WHERE owner_category = 'Component'
    """
    query_attributes = """
        SELECT
            COUNT(DISTINCT owner_uuid) AS count
        FROM $ASSOCIATIONS_TABLE_NAME
        WHERE owner_category = 'SupplementalAttribute'
    """
    query_sts = """
        SELECT
            COUNT(DISTINCT time_series_uuid) AS count
        FROM $ASSOCIATIONS_TABLE_NAME
        WHERE interval_ms IS NULL
    """
    query_forecasts = """
        SELECT
            COUNT(DISTINCT time_series_uuid) AS count
        FROM $ASSOCIATIONS_TABLE_NAME
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
        FROM $ASSOCIATIONS_TABLE_NAME
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
Return a DataFrame with the number of static time series for components and supplemental
attributes.
"""
function get_static_time_series_summary_table(store::TimeSeriesMetadataStore)
    query = """
        SELECT
            owner_type
            ,owner_category
            ,time_series_type
            ,initial_timestamp
            ,resolution_ms AS resolution
            ,count(*) AS count
            ,length AS time_step_count
        FROM $ASSOCIATIONS_TABLE_NAME
        WHERE time_series_category = "$(_get_time_series_category(StaticTimeSeries))"
        GROUP BY
            owner_type
            ,owner_category
            ,time_series_type
            ,initial_timestamp
            ,resolution_ms
            ,length
        ORDER BY
            owner_category
            ,owner_type
            ,time_series_type
            ,initial_timestamp
            ,resolution_ms
            ,length
    """
    query_result = DataFrame(_execute(store, query))
    query_result[!, "resolution"] =
        Dates.canonicalize.(Dates.Millisecond.(query_result[!, "resolution"]))
    return query_result
end

"""
Return a DataFrame with the number of forecasts for components and supplemental
attributes.
"""
function get_forecast_summary_table(store::TimeSeriesMetadataStore)
    query = """
        SELECT
            owner_type
            ,owner_category
            ,time_series_type
            ,initial_timestamp
            ,resolution_ms AS resolution
            ,count(*) AS count
            ,horizon_ms AS horizon
            ,interval_ms AS interval
            ,window_count
        FROM $ASSOCIATIONS_TABLE_NAME
        WHERE time_series_category = "$(_get_time_series_category(Forecast))"
        GROUP BY
            owner_type
            ,owner_category
            ,time_series_type
            ,initial_timestamp
            ,resolution_ms
            ,horizon_ms
            ,interval_ms
            ,window_count
        ORDER BY
            owner_category
            ,owner_type
            ,time_series_type
            ,initial_timestamp
            ,resolution_ms
            ,horizon_ms
            ,interval_ms
            ,window_count
    """
    query_result = DataFrame(_execute(store, query))
    for col_name in ["resolution", "horizon", "interval"]
        query_result[!, col_name] =
            Dates.canonicalize.(Dates.Millisecond.(query_result[!, col_name]))
    end
    return query_result
end

function has_metadata(
    store::TimeSeriesMetadataStore,
    owner::TimeSeriesOwners;
    time_series_type::Union{Type{<:TimeSeriesData}, Nothing} = nothing,
    name::Union{String, Nothing} = nothing,
    resolution::Union{Nothing, Dates.Period} = nothing,
    features...,
)
    params = _make_has_metadata_params(owner, time_series_type, name, resolution)
    if isempty(features)
        stmt = _make_has_metadata_statement!(
            store,
            HasMetadataQueryKey(;
                has_name = !isnothing(name),
                num_possible_types = _get_num_possible_types(time_series_type),
                has_resolution = !isnothing(resolution),
                has_features = false,
            ),
        )
        return _has_metadata(stmt, params)
    end

    # It's worth trying full features first because we can get an index hit and
    # avoid JSON parsing.
    stmt = _make_has_metadata_statement!(
        store,
        HasMetadataQueryKey(;
            has_name = !isnothing(name),
            num_possible_types = _get_num_possible_types(time_series_type),
            has_resolution = !isnothing(resolution),
            has_features = true,
        ),
    )
    full_features = make_features_string(; features...)
    if _has_metadata(stmt, (params..., full_features))
        return true
    end

    params2 = collect(params)
    feature_filter = _make_feature_filter!(params2; features...)
    stmt = _make_has_metadata_statement!(
        store,
        HasMetadataQueryKey(;
            has_name = !isnothing(name),
            num_possible_types = _get_num_possible_types(time_series_type),
            has_resolution = !isnothing(resolution),
            has_features = true,
            feature_filter = feature_filter,
        ),
    )
    return _has_metadata(stmt, params2)
end

const _QUERY_HAS_METADATA_BY_TS_UUID = "SELECT id FROM $ASSOCIATIONS_TABLE_NAME WHERE time_series_uuid = ?"

"""
Return True if there is time series matching the UUID.
"""
function has_metadata(store::TimeSeriesMetadataStore, time_series_uuid::Base.UUID)
    params = (string(time_series_uuid),)
    return _has_metadata(store, _QUERY_HAS_METADATA_BY_TS_UUID, params)
end

const _QUERY_BASE_HAS_METADATA = "SELECT id FROM $ASSOCIATIONS_TABLE_NAME WHERE owner_uuid = ?"

function _make_has_metadata_statement!(
    store::TimeSeriesMetadataStore,
    key::HasMetadataQueryKey;
)
    stmt = get(store.has_metadata_statements, key, nothing)
    if !isnothing(stmt)
        return stmt
    end

    where_clauses = String[]
    if key.has_name
        push!(where_clauses, "name = ?")
    end
    if key.num_possible_types == 1
        push!(where_clauses, "time_series_type = ?")
    elseif key.num_possible_types > 1
        val = chop(repeat("?,", key.num_possible_types))
        push!(where_clauses, "time_series_type IN ($val)")
    end
    if key.has_resolution
        push!(where_clauses, "resolution_ms = ?")
    end
    if key.has_features
        if isnothing(key.feature_filter)
            push!(where_clauses, "features = ?")
        else
            push!(where_clauses, "$(key.feature_filter)")
        end
    end

    if isempty(where_clauses)
        final = "$_QUERY_BASE_HAS_METADATA LIMIT 1"
    else
        where_clause = join(where_clauses, " AND ")
        final = "$_QUERY_BASE_HAS_METADATA AND $where_clause LIMIT 1"
    end

    stmt = SQLite.Stmt(store.db, final)
    store.has_metadata_statements[key] = stmt
    return stmt
end

function _make_has_metadata_params(
    owner::TimeSeriesOwners,
    time_series_type::Union{Type{<:TimeSeriesData}, Nothing},
    name::Union{String, Nothing},
    resolution::Union{Dates.Period, Nothing};
    feature_value::Union{String, Nothing} = nothing,
)
    return (
        string(get_uuid(owner)),
        _get_name_params(name)...,
        _get_ts_type_params(time_series_type)...,
        _get_resolution_param(resolution)...,
        _get_feature_params(feature_value)...,
    )
end

_get_name_params(::Nothing) = ()
_get_name_params(name::String) = (name,)
_get_resolution_param(::Nothing) = ()
_get_resolution_param(x::Dates.Period) = (Dates.Millisecond(x).value,)
_get_ts_type_params(::Nothing) = ()
_get_ts_type_params(ts_type::Type{<:TimeSeriesData}) =
    (_convert_ts_type_to_string(ts_type),)
_get_ts_type_params(ts_type::Type{<:DeterministicSingleTimeSeries}) =
    (_convert_ts_type_to_string(ts_type),)
_get_feature_params(::Nothing) = ()
_get_feature_params(feature::String) = (feature,)

function _get_ts_type_params(::Type{<:AbstractDeterministic})
    return (
        _convert_ts_type_to_string(Deterministic),
        _convert_ts_type_to_string(DeterministicSingleTimeSeries),
    )
end

_get_num_possible_types(::Nothing) = 0
_get_num_possible_types(::Type{<:TimeSeriesData}) = 1
_get_num_possible_types(::Type{<:DeterministicSingleTimeSeries}) = 1
_get_num_possible_types(::Type{<:AbstractDeterministic}) = 2

function _has_metadata(stmt::SQLite.Stmt, params)
    return !isempty(SQLite.DBInterface.execute(stmt, params))
end

function _has_metadata(store::TimeSeriesMetadataStore, query::String, params)
    return !isempty(_execute_cached(store, query, params))
end

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
        FROM $ASSOCIATIONS_TABLE_NAME $where_clause
        ORDER BY resolution_ms
    """
    return Dates.Millisecond.(
        Tables.columntable(_execute(store, query, params)).resolution_ms
    )
end

"""
Return the time series UUIDs specified in the passed uuids that are already stored.
"""
function list_existing_time_series_uuids(store::TimeSeriesMetadataStore, uuids)
    uuids_str = string.(uuids)
    placeholder = chop(repeat("?,", length(uuids)))
    query = """
        SELECT
            DISTINCT time_series_uuid
            FROM $ASSOCIATIONS_TABLE_NAME
            WHERE time_series_uuid IN ($placeholder)
    """
    table = Tables.columntable(_execute_cached(store, query, uuids_str))
    return Base.UUID.(table.time_series_uuid)
end

const _QUERY_LIST_EXISTING_TS_UUIDS = "SELECT DISTINCT time_series_uuid FROM $ASSOCIATIONS_TABLE_NAME"

function list_existing_time_series_uuids(store::TimeSeriesMetadataStore)
    table = Tables.columntable(_execute_cached(store, _QUERY_LIST_EXISTING_TS_UUIDS))
    return Base.UUID.(table.time_series_uuid)
end

"""
Return the time series UUIDs that match the inputs.
"""
function list_matching_time_series_uuids(
    store::TimeSeriesMetadataStore;
    time_series_type::Union{Type{<:TimeSeriesData}, Nothing} = nothing,
    name::Union{String, Nothing} = nothing,
    resolution::Union{Dates.Period, Nothing} = nothing,
    features...,
)
    where_clause, params = _make_where_clause(;
        time_series_type = time_series_type,
        name = name,
        resolution = resolution,
        features...,
    )
    query = "SELECT DISTINCT time_series_uuid FROM $ASSOCIATIONS_TABLE_NAME $where_clause"
    table = Tables.columntable(_execute(store, query, params))
    return Base.UUID.(table.time_series_uuid)
end

function list_metadata(
    store::TimeSeriesMetadataStore,
    owner::TimeSeriesOwners;
    time_series_type::Union{Type{<:TimeSeriesData}, Nothing} = nothing,
    name::Union{String, Nothing} = nothing,
    resolution::Union{Dates.Period, Nothing} = nothing,
    features...,
)
    where_clause, params = _make_where_clause(
        owner;
        time_series_type = time_series_type,
        name = name,
        resolution = resolution,
        features...,
    )
    query = """
        SELECT metadata_uuid
        FROM $ASSOCIATIONS_TABLE_NAME
        $where_clause
    """
    table = Tables.rowtable(_execute_cached(store, query, params))
    return [store.metadata_uuids[Base.UUID(x.metadata_uuid)] for x in table]
end

"""
Return a Vector of NamedTuple of owner UUID and time series metadata matching the inputs.
"""
function list_metadata_with_owner_uuid(
    store::TimeSeriesMetadataStore,
    owner_type::Type{<:TimeSeriesOwners};
    time_series_type::Union{Type{<:TimeSeriesData}, Nothing} = nothing,
    name::Union{String, Nothing} = nothing,
    resolution::Union{Dates.Period, Nothing} = nothing,
    features...,
)
    where_clause, params = _make_where_clause(
        owner_type;
        time_series_type = time_series_type,
        name = name,
        resolution = resolution,
        features...,
    )
    query = """
        SELECT owner_uuid, metadata_uuid
        FROM $ASSOCIATIONS_TABLE_NAME
        $where_clause
    """
    table = Tables.rowtable(_execute(store, query, params))
    return [
        (
            owner_uuid = Base.UUID(x.owner_uuid),
            metadata = store.metadata_uuids[Base.UUID(x.metadata_uuid)],
        ) for x in table
    ]
end

function list_owner_uuids_with_time_series(
    store::TimeSeriesMetadataStore,
    owner_type::Type{<:TimeSeriesOwners};
    time_series_type::Union{Nothing, Type{<:TimeSeriesData}} = nothing,
    resolution::Union{Nothing, Dates.Period} = nothing,
)
    category = _get_owner_category(owner_type)
    vals = ["owner_category = ?"]
    params = Vector{Any}([category])
    if !isnothing(time_series_type)
        push!(vals, "time_series_type = ?")
        push!(params, string(nameof(time_series_type)))
    end
    if !isnothing(resolution)
        push!(vals, "resolution_ms = ?")
        push!(params, Dates.Millisecond(resolution).value)
    end

    where_clause = join(vals, " AND ")
    query = """
        SELECT
            DISTINCT owner_uuid
        FROM $ASSOCIATIONS_TABLE_NAME
        WHERE $where_clause
    """
    return Base.UUID.(Tables.columntable(_execute(store, query, params)).owner_uuid)
end

"""
Return information about each time series array attached to the owner.
This information can be used to call `get_time_series`.
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

    _handle_removed_metadata(store, string(get_uuid(metadata)))
end

function remove_metadata!(
    store::TimeSeriesMetadataStore,
    owner::TimeSeriesOwners;
    time_series_type::Union{Type{<:TimeSeriesData}, Nothing} = nothing,
    name::Union{String, Nothing} = nothing,
    resolution::Union{Dates.Period, Nothing} = nothing,
    features...,
)
    where_clause, params = _make_where_clause(
        owner;
        time_series_type = time_series_type,
        name = name,
        resolution = resolution,
        # TODO/PERF: This can be made faster by attempting search by a full match
        # and then fallback to partial. We likely don't care about this for removing.
        require_full_feature_match = false,
        features...,
    )

    # The metadata in the rows about to be deleted need to be deleted if there are no more
    # associations with them.
    metadata_uuids =
        Tables.columntable(
            _execute(
                store,
                "SELECT metadata_uuid FROM $ASSOCIATIONS_TABLE_NAME $where_clause",
                params,
            ),
        ).metadata_uuid
    num_deleted = _remove_metadata!(store, where_clause, params)
    if num_deleted == 0
        @warn "No time series metadata was deleted."
    else
        for metadata_uuid in metadata_uuids
            _handle_removed_metadata(store, metadata_uuid)
        end
    end
end

function _handle_removed_metadata(store::TimeSeriesMetadataStore, metadata_uuid::String)
    query = "SELECT count(*) FROM $ASSOCIATIONS_TABLE_NAME WHERE metadata_uuid = ?"
    params = (metadata_uuid,)
    if isempty(_execute_cached(store, query, params))
        pop!(store.metadata_uuids, Base.UUID(metadata_uuid))
    end
end

const _QUERY_REPLACE_COMP_UUID_TS = """
    UPDATE $ASSOCIATIONS_TABLE_NAME
    SET owner_uuid = ?
    WHERE owner_uuid = ?
"""
function replace_component_uuid!(
    store::TimeSeriesMetadataStore,
    old_uuid::Base.UUID,
    new_uuid::Base.UUID,
)
    params = (string(new_uuid), string(old_uuid))
    _execute(store, _QUERY_REPLACE_COMP_UUID_TS, params)
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
        Dates.Millisecond(get_horizon(metadata)).value,
        Dates.Millisecond(get_interval(metadata)).value,
        get_count(metadata),
        missing,
        get_name(metadata),
        string(get_uuid(owner)),
        string(nameof(typeof(owner))),
        owner_category,
        features,
        string(get_uuid(metadata)),
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
        string(get_uuid(metadata)),
    )
end

function make_stmt(store::TimeSeriesMetadataStore, query::String)
    return get!(() -> SQLite.Stmt(store.db, query), store.cached_statements, query)
end

_execute_cached(s::TimeSeriesMetadataStore, q, p = nothing) =
    execute(make_stmt(s, q), p, LOG_GROUP_TIME_SERIES)
_execute(s::TimeSeriesMetadataStore, q, p = nothing) =
    execute(s.db, q, p, LOG_GROUP_TIME_SERIES)
_execute_count(s::TimeSeriesMetadataStore, q, p = nothing) =
    execute_count(s.db, q, p, LOG_GROUP_TIME_SERIES)

function _remove_metadata!(
    store::TimeSeriesMetadataStore,
    where_clause::AbstractString,
    params,
)
    _execute(store, "DELETE FROM $ASSOCIATIONS_TABLE_NAME $where_clause", params)
    table = Tables.rowtable(_execute(store, "SELECT CHANGES() AS changes"))
    @assert_op length(table) == 1
    @debug "Deleted $(table[1].changes) rows from the time series associations table" _group =
        LOG_GROUP_TIME_SERIES
    return table[1].changes
end

function _try_get_time_series_metadata_by_full_params(
    store::TimeSeriesMetadataStore,
    owner::TimeSeriesOwners,
    time_series_type::Type{<:TimeSeriesData},
    name::String;
    resolution::Union{Nothing, Dates.Period} = nothing,
    features...,
)
    where_clause, params = _make_where_clause(
        owner;
        time_series_type = time_series_type,
        name = name,
        resolution = resolution,
        require_full_feature_match = true,
        features...,
    )
    query = "SELECT metadata_uuid FROM $ASSOCIATIONS_TABLE_NAME $where_clause"
    rows = Tables.rowtable(_execute_cached(store, query, params))
    len = length(rows)
    if len == 0
        return nothing
    elseif len == 1
        return store.metadata_uuids[Base.UUID(rows[1].metadata_uuid)]
    else
        throw(ArgumentError("Found more than one matching time series: $len"))
    end
end

function compare_values(
    match_fn::Union{Function, Nothing},
    x::TimeSeriesMetadataStore,
    y::TimeSeriesMetadataStore;
    compare_uuids = false,
    exclude = Set{Symbol}(),
)
    # Note that we can't compare missing values.
    owner_uuid = compare_uuids ? ", owner_uuid" : ""
    query = """
        SELECT id, metadata_uuid, time_series_uuid $owner_uuid
        FROM $ASSOCIATIONS_TABLE_NAME ORDER BY id
    """
    table_x = Tables.rowtable(_execute(x, query))
    table_y = Tables.rowtable(_execute(y, query))
    match_fn = _fetch_match_fn(match_fn)
    return match_fn(table_x, table_y)
end

### Non-TimeSeriesMetadataStore functions ###

const _DETERMINISTIC_AS_STRING = string(nameof(Deterministic))
const _DETERMINISTIC_STS_AS_STRING = string(nameof(DeterministicSingleTimeSeries))
const _STS_AS_STRING = string(nameof(SingleTimeSeries))
const _PROBABILISTIC_AS_STRING = string(nameof(Probabilistic))
const _SCENARIOS_AS_STRING = string(nameof(Scenarios))

_convert_ts_type_to_string(ts_type::Type{<:TimeSeriesData}) = string(nameof(ts_type))
_convert_ts_type_to_string(::Type{<:Deterministic}) = _DETERMINISTIC_AS_STRING
_convert_ts_type_to_string(::Type{<:DeterministicSingleTimeSeries}) =
    _DETERMINISTIC_STS_AS_STRING
_convert_ts_type_to_string(::Type{<:Probabilistic}) = _PROBABILISTIC_AS_STRING
_convert_ts_type_to_string(::Type{<:Scenarios}) = _SCENARIOS_AS_STRING

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
        push!(strings, "features LIKE ?")
        if val isa AbstractString
            push!(params, "%$(key)\":\"%$(val)%")
        else
            push!(params, "%$(key)\":$(val)%")
        end
    end
    return join(strings, " AND ")
end

_make_val_str(val::Union{Bool, Int}) = string(val)
_make_val_str(val::String) = "'$val'"

function _make_sorted_feature_array(; features...)
    key_names = sort!(collect(string.(keys(features))))
    return [(key, features[Symbol(key)]) for key in key_names]
end

function _make_where_clause(
    owner_type::Type{<:TimeSeriesOwners};
    time_series_type::Union{Type{<:TimeSeriesData}, Nothing} = nothing,
    name::Union{String, Nothing} = nothing,
    resolution::Union{Nothing, Dates.Period} = nothing,
    require_full_feature_match = false,
    features...,
)
    params = Vector{Any}([_get_owner_category(owner_type)])
    return _make_where_clause(;
        owner_clause = "owner_category = ?",
        time_series_type = time_series_type,
        name = name,
        resolution = resolution,
        require_full_feature_match = require_full_feature_match,
        params = params,
        features...,
    )
end

function _make_where_clause(
    owner::TimeSeriesOwners;
    time_series_type::Union{Type{<:TimeSeriesData}, Nothing} = nothing,
    name::Union{String, Nothing} = nothing,
    resolution::Union{Nothing, Dates.Period} = nothing,
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
        resolution = resolution,
        require_full_feature_match = require_full_feature_match,
        params = params,
        features...,
    )
end

function _make_where_clause(;
    owner_clause::Union{String, Nothing} = nothing,
    time_series_type::Union{Type{<:TimeSeriesData}, Nothing} = nothing,
    name::Union{String, Nothing} = nothing,
    resolution::Union{Nothing, Dates.Period} = nothing,
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
    if !isnothing(resolution)
        push!(vals, "resolution_ms = ?")
        push!(params, Dates.Millisecond(resolution).value)
    end
    num_possible_types = _get_num_possible_types(time_series_type)
    if num_possible_types == 1
        push!(vals, "time_series_type = ?")
        push!(params, _convert_ts_type_to_string(time_series_type))
    elseif num_possible_types > 1
        val = chop(repeat("?,", num_possible_types))
        push!(vals, "time_series_type IN ($val)")
        for val in _get_ts_type_params(time_series_type)
            push!(params, val)
        end
    end
    if !isempty(features)
        if require_full_feature_match
            val = "features = ?"
            push!(params, make_features_string(; features...))
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
        resolution = get_resolution(metadata),
        features...,
    )
end
