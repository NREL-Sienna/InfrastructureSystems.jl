const METADATA_TABLE_NAME = "time_series_metadata"
const DB_FILENAME = "time_series_metadata.db"

mutable struct TimeSeriesMetadataStore
    db::SQLite.DB
end

function TimeSeriesMetadataStore(filename::AbstractString)
    # An ideal solution would be to create an in-memory database and then perform a SQLite
    # backup to a file whenever the user serializes the system. However, SQLite.jl does
    # not support that feature yet: https://github.com/JuliaDatabases/SQLite.jl/issues/210
    store = TimeSeriesMetadataStore(SQLite.DB(filename))
    _create_metadata_table!(store)
    _create_indexes!(store)
    @debug "Initializedd new time series metadata table" _group = LOG_GROUP_TIME_SERIES
    return store
end

function from_file(::Type{TimeSeriesMetadataStore}, filename::AbstractString)
    store = TimeSeriesMetadataStore(SQLite.DB(filename))
    @debug "Loaded time series metadata from file" _group = LOG_GROUP_TIME_SERIES filename
    return store
end

function from_h5_file(::Type{TimeSeriesMetadataStore}, src::AbstractString, directory)
    data = HDF5.h5open(src, "r") do file
        file[HDF5_TS_METADATA_ROOT_PATH][:]
    end

    filename, io = mktemp(isnothing(directory) ? tempdir() : directory)
    write(io, data)
    close(io)
    return from_file(TimeSeriesMetadataStore, filename)
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
        "horizon INTEGER",
        "horizon_time_ms INTEGER",
        "interval_ms INTEGER",
        "window_count INTEGER",
        "length INTEGER",
        "name TEXT NOT NULL",
        "owner_uuid TEXT NOT NULL",
        "owner_type TEXT NOT NULL",
        "owner_category TEXT NOT NULL",
        "features TEXT NOT NULL",
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
    SQLite.createindex!(store.db, METADATA_TABLE_NAME, "by_id", "id"; unique = true)
    SQLite.createindex!(store.db, METADATA_TABLE_NAME, "by_c", "owner_uuid"; unique = false)
    SQLite.createindex!(
        store.db,
        METADATA_TABLE_NAME,
        "by_c_n_tst",
        ["owner_uuid", "name", "time_series_type"];
        unique = false,
    )
    SQLite.createindex!(
        store.db,
        METADATA_TABLE_NAME,
        "by_c_n_tst_features",
        ["owner_uuid", "name", "time_series_type", "features"];
        unique = false,
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

"""
Add metadata to the store.
"""
function add_metadata!(
    store::TimeSeriesMetadataStore,
    owner::TimeSeriesOwners,
    metadata::TimeSeriesMetadata;
)
    if has_metadata(store, owner, metadata)
        throw(ArgumentError("time_series $(summary(metadata)) is already stored"))
    end

    check_params_compatibility(store, metadata)
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
    params = chop(repeat("?,", length(vals)))
    SQLite.DBInterface.execute(
        store.db,
        "INSERT INTO $METADATA_TABLE_NAME VALUES($params)",
        vals,
    )
    @debug "Added metadata = $metadata to $(summary(owner))" _group =
        LOG_GROUP_TIME_SERIES
    return
end

"""
Clear all time series metadata from the store.
"""
function clear_metadata!(store::TimeSeriesMetadataStore)
    _execute(store, "DELETE FROM $METADATA_TABLE_NAME")
end

function backup(store::TimeSeriesMetadataStore, filename::String)
    # This is an unfortunate implementation. SQLite supports backup but SQLite.jl does not.
    # https://github.com/JuliaDatabases/SQLite.jl/issues/210
    # When they address the limitation, search the IS repo for this github issue number
    # to fix all locations.
    was_open = isopen(store.db)
    if was_open
        close(store.db)
    end

    cp(store.db.file, filename)
    @debug "Backed up time series metadata" _group = LOG_GROUP_TIME_SERIES filename

    if was_open
        store.db = SQLite.DB(store.db.file)
    end

    return
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

    if params.count != store_params.count
        throw(
            ConflictingInputsError(
                "forecast count $(params.count) does not match system count $(store_params.count)",
            ),
        )
    end

    if params.initial_timestamp != store_params.initial_timestamp
        throw(
            ConflictingInputsError(
                "forecast initial_timestamp $(params.initial_timestamp) does not match system " *
                "initial_timestamp $(store_params.initial_timestamp)",
            ),
        )
    end

    horizon_as_time = params.horizon * params.resolution
    store_horizon_as_time = store_params.horizon * store_params.resolution
    if horizon_as_time != store_horizon_as_time
        throw(
            ConflictingInputsError(
                "forecast horizon $(horizon_as_time) " *
                "does not match system horizon $(store_horizon_as_time)",
            ),
        )
    end
end

# These are guaranteed to be consistent already.
check_consistency(::TimeSeriesMetadataStore, ::Type{<:Forecast}) = nothing

"""
Throw InvalidValue if the SingleTimeSeries arrays have different initial times or lengths.
Return the initial timestamp and length as a tuple.
"""
function check_consistency(store::TimeSeriesMetadataStore, ::Type{<:StaticTimeSeries})
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

function close_temporarily!(func::Function, store::TimeSeriesMetadataStore)
    try
        close(store.db)
        func()
    finally
        store.db = SQLite.DB(store.db.file)
    end
end

function get_forecast_initial_times(store::TimeSeriesMetadataStore)
    params = get_forecast_parameters(store)
    isnothing(params) && return []
    return get_initial_times(params.initial_timestamp, params.count, params.interval)
end

function get_forecast_parameters(store::TimeSeriesMetadataStore)
    query = """
        SELECT
            horizon
            ,initial_timestamp
            ,interval_ms
            ,resolution_ms
            ,window_count
        FROM $METADATA_TABLE_NAME
        WHERE horizon IS NOT NULL
        LIMIT 1
        """
    table = Tables.rowtable(_execute(store, query))
    isempty(table) && return nothing
    row = table[1]
    return ForecastParameters(;
        horizon = row.horizon,
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
    return isempty(table) ? 0 : table[1].window_count
end

function get_forecast_horizon(store::TimeSeriesMetadataStore)
    query = """
        SELECT
            horizon
        FROM $METADATA_TABLE_NAME
        WHERE horizon IS NOT NULL
        LIMIT 1
        """
    table = Tables.rowtable(_execute(store, query))
    return isempty(table) ? 0 : table[1].horizon
end

function get_forecast_initial_timestamp(store::TimeSeriesMetadataStore)
    query = """
        SELECT
            initial_timestamp
        FROM $METADATA_TABLE_NAME
        WHERE horizon IS NOT NULL
        LIMIT 1
        """
    table = Tables.rowtable(_execute(store, query))
    return if isempty(table)
        Dates.DateTime(Dates.Minute(0))
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
        Dates.Period(Dates.Millisecond(0))
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
            # This is a hack to account for the fact that we allow non-standard behavior
            # with DeterministicSingleTimeSeries.
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
    return has_metadata(
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

    where_clause = _make_where_clause(
        owner;
        time_series_type = time_series_type,
        name = name,
        features...,
    )
    query = "SELECT COUNT(*) AS count FROM $METADATA_TABLE_NAME WHERE $where_clause"
    return _execute_count(store, query) > 0
end

"""
Return True if there is time series matching the UUID.
"""
function has_time_series(store::TimeSeriesMetadataStore, time_series_uuid::Base.UUID)
    where_clause = "time_series_uuid = '$time_series_uuid'"
    return _has_time_series(store, where_clause)
end

function has_time_series(
    store::TimeSeriesMetadataStore,
    owner::TimeSeriesOwners,
)
    where_clause = _make_owner_where_clause(owner)
    return _has_time_series(store, where_clause)
end

function has_time_series(
    store::TimeSeriesMetadataStore,
    owner::TimeSeriesOwners,
    time_series_type::Type{<:TimeSeriesData},
)
    where_clause = _make_where_clause(owner; time_series_type = time_series_type)
    return _has_time_series(store, where_clause)
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
function list_time_series_resolutions(
    store::TimeSeriesMetadataStore;
    time_series_type::Union{Type{<:TimeSeriesData}, Nothing} = nothing,
)
    where_clause = if isnothing(time_series_type)
        ""
    else
        "WHERE time_series_type = '$(nameof(time_series_type))'"
    end
    query = """
        SELECT
            DISTINCT resolution_ms
        FROM $METADATA_TABLE_NAME $where_clause
        ORDER BY resolution_ms
    """
    return Dates.Millisecond.(Tables.columntable(_execute(store, query)).resolution_ms)
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
    where_clause = _make_where_clause(
        nothing;
        time_series_type = time_series_type,
        name = name,
        features...,
    )
    query = "SELECT DISTINCT time_series_uuid FROM $METADATA_TABLE_NAME WHERE $where_clause"
    table = Tables.columntable(_execute(store, query))
    return Base.UUID.(table.time_series_uuid)
end

function list_metadata(
    store::TimeSeriesMetadataStore,
    owner::TimeSeriesOwners;
    time_series_type::Union{Type{<:TimeSeriesData}, Nothing} = nothing,
    name::Union{String, Nothing} = nothing,
    features...,
)
    where_clause = _make_where_clause(
        owner;
        time_series_type = time_series_type,
        name = name,
        features...,
    )
    query = "SELECT metadata FROM $METADATA_TABLE_NAME WHERE $where_clause"
    table = Tables.rowtable(_execute(store, query))
    return [_deserialize_metadata(x.metadata) for x in table]
end

function list_owner_uuids_with_time_series(
    store::TimeSeriesMetadataStore,
    owner_type::Type{<:TimeSeriesOwners};
    time_series_type::Union{Nothing, Type{<:TimeSeriesData}} = nothing,
)
    category = _get_owner_category(owner_type)
    vals = ["owner_category = '$category'"]
    if !isnothing(time_series_type)
        push!(vals, "time_series_type = '$(nameof(time_series_type))'")
    end

    where_clause = join(vals, " AND ")
    query = """
        SELECT
            DISTINCT owner_uuid
        FROM $METADATA_TABLE_NAME
        WHERE $where_clause
    """
    return Base.UUID.(Tables.columntable(_execute(store, query)).owner_uuid)
end

"""
Return information about each time series array attached to the owner.
This information can be used to call get_time_series.
"""
function list_time_series_info(store::TimeSeriesMetadataStore, owner::TimeSeriesOwners)
    return [make_time_series_info(x) for x in list_metadata(store, owner)]
end

"""
Remove the matching metadata from the store.
"""
function remove_metadata!(
    store::TimeSeriesMetadataStore,
    owner::TimeSeriesOwners,
    metadata::TimeSeriesMetadata,
)
    where_clause = _make_where_clause(owner, metadata)
    num_deleted = _remove_metadata!(store, where_clause)
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
    where_clause = _make_where_clause(
        owner;
        time_series_type = time_series_type,
        name = name,
        require_full_feature_match = false,  # TODO: needs more consideration
        features...,
    )
    num_deleted = _remove_metadata!(store, where_clause)
    if num_deleted == 0
        if time_series_type === Deterministic
            # This is a hack to account for the fact that we allow non-standard behavior
            # with DeterministicSingleTimeSeries.
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
        SET owner_uuid = '$new_uuid'
        WHERE owner_uuid = '$old_uuid'
    """
    _execute(store, query)
    return
end

"""
Run a query and return the results in a DataFrame.
"""
function sql(store::TimeSeriesMetadataStore, query::String)
    """Run a SQL query on the time series metadata table."""
    return DataFrames.DataFrame(_execute(store, query))
end

function to_h5_file(store::TimeSeriesMetadataStore, dst::String)
    metadata_path, io = mktemp()
    close(io)
    rm(metadata_path)
    backup(store, metadata_path)

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
        get_horizon(metadata),
        Dates.Millisecond(get_horizon(metadata) * get_resolution(metadata)).value,
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

function _execute(store::TimeSeriesMetadataStore, query::AbstractString)
    @debug "Run SQL" query _group = LOG_GROUP_TIME_SERIES
    res = SQLite.DBInterface.execute(store.db, query)
    return res
end

function _execute_count(store::TimeSeriesMetadataStore, query::AbstractString)
    for row in Tables.rows(_execute(store, query))
        return row.count
    end

    error("Bug: unexpectedly did not receive any rows")
end

function _has_time_series(store::TimeSeriesMetadataStore, where_clause::String)
    query = "SELECT COUNT(*) AS count FROM $METADATA_TABLE_NAME WHERE $where_clause"
    return _execute_count(store, query) > 0
end

function _remove_metadata!(
    store::TimeSeriesMetadataStore,
    where_clause::AbstractString,
)
    _execute(store, "DELETE FROM $METADATA_TABLE_NAME WHERE $where_clause")
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
        "metadata";
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
    where_clause = _make_where_clause(
        owner;
        time_series_type = time_series_type,
        name = name,
        require_full_feature_match = true,
        features...,
    )
    query = "SELECT $column FROM $METADATA_TABLE_NAME WHERE $where_clause"
    return Tables.rowtable(_execute(store, query))
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

function _make_feature_filter(; features...)
    data = _make_sorted_feature_array(; features...)
    return join((["metadata->>'\$.features.$k' = '$v'" for (k, v) in data]), "AND ")
end

function _make_features_string(features::Dict{String, <:Any})
    key_names = sort!(collect(keys(features)))
    data = [Dict(k => features[k]) for k in key_names]
    return JSON3.write(data)
end

function _make_features_string(; features...)
    key_names = sort!(collect(string.(keys(features))))
    data = [Dict(k => features[Symbol(k)]) for (k) in key_names]
    return JSON3.write(data)
end

_make_owner_where_clause(owner::TimeSeriesOwners) =
    "owner_uuid = '$(get_uuid(owner))'"

function _make_sorted_feature_array(; features...)
    key_names = sort!(collect(string.(keys(features))))
    return [(key, features[Symbol(key)]) for key in key_names]
end

function _make_where_clause(
    owner::Union{TimeSeriesOwners, Nothing};
    time_series_type::Union{Type{<:TimeSeriesData}, Nothing} = nothing,
    name::Union{String, Nothing} = nothing,
    require_full_feature_match = false,
    features...,
)
    vals = String[]
    if !isnothing(owner)
        push!(vals, _make_owner_where_clause(owner))
    end
    if !isnothing(name)
        push!(vals, "name = '$name'")
    end
    if !isnothing(time_series_type)
        push!(vals, "time_series_type = '$(_convert_ts_type_to_string(time_series_type))'")
    end
    if !isempty(features)
        if require_full_feature_match
            val = "features = '$(_make_features_string(; features...))'"
        else
            val = "$(_make_feature_filter(; features...))"
        end
        push!(vals, val)
    end

    return "(" * join(vals, " AND ") * ")"
end

function _make_where_clause(owner::TimeSeriesOwners, metadata::TimeSeriesMetadata)
    return _make_where_clause(
        owner;
        time_series_type = time_series_metadata_to_data(metadata),
        name = get_name(metadata),
        get_features(metadata)...,
    )
end
