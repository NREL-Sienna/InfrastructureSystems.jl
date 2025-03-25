const SUPPLEMENTAL_ATTRIBUTE_TABLE_NAME = "supplemental_attributes"

# Design note:
# Supplemental attributes and time series are stored in independent SQLite databases.
# Ideally, they would be different tables in the same database. This is not practical
# because of requirements set by the team for serialization output files.
#
# Background:
#   - Time series metadata is always persisted as a SQLite file during serialization.
#   - That SQLite file is written as an HDF5 dataset in the time series data file.
#   - The result of serialization is system.json, system_metadata.json, and
#     system_time_series.h5.
#   - If there is no time series in the system, then there is no extra file: only
#     system.json and system_metadata.json.
#
# If we persist supplemental attribute associations to a SQLite file and there is no time
# series, serialization would produce an extra file. The team was strongly opposed to this
# and set a requirement that those associations must be written to the system JSON file.
#
# Rather than try to manage the complexities of temporarily sharing a database across
# serialization and deepcopy operations, this design keeps them separate in order to 
# simplifiy the code. The supplemental attribute database is always ephemeral.

mutable struct SupplementalAttributeAssociations
    db::SQLite.DB
    # If we don't cache SQL statements, there is a cost of 3-4 us on every query.
    cached_statements::Dict{String, SQLite.Stmt}
    # If you add any fields, ensure they are managed in deepcopy_internal below.
end

"""
Construct a new SupplementalAttributeAssociations with an in-memory database.
"""
function SupplementalAttributeAssociations(; create_indexes = true)
    associations =
        SupplementalAttributeAssociations(SQLite.DB(), Dict{String, SQLite.Stmt}())
    _create_attribute_associations_table!(associations)
    if create_indexes
        _create_indexes!(associations)
    end
    @debug "Initialized new supplemental attributes association table" _group =
        LOG_GROUP_SUPPLEMENTAL_ATTRIBUTES
    return associations
end

function _create_attribute_associations_table!(
    associations::SupplementalAttributeAssociations,
)
    schema = [
        "attribute_uuid TEXT NOT NULL",
        "attribute_type TEXT NOT NULL",
        "component_uuid TEXT NOT NULL",
        "component_type TEXT NOT NULL",
    ]
    schema_text = join(schema, ",")
    _execute(
        associations,
        "CREATE TABLE $(SUPPLEMENTAL_ATTRIBUTE_TABLE_NAME)($(schema_text))",
    )
    @debug "Created supplemental attribute association table" schema _group =
        LOG_GROUP_SUPPLEMENTAL_ATTRIBUTES
    return
end

function _create_indexes!(associations::SupplementalAttributeAssociations)
    SQLite.createindex!(
        associations.db,
        SUPPLEMENTAL_ATTRIBUTE_TABLE_NAME,
        "by_attribute",
        [
            "attribute_uuid",
            "component_uuid",
            "component_type",
        ];
        unique = false,
    )
    SQLite.createindex!(
        associations.db,
        SUPPLEMENTAL_ATTRIBUTE_TABLE_NAME,
        "by_component",
        [
            "component_uuid",
            "attribute_uuid",
            "attribute_type",
        ];
        unique = false,
    )
    return
end

function Base.deepcopy_internal(val::SupplementalAttributeAssociations, dict::IdDict)
    if haskey(dict, val)
        return dict[val]
    end
    new_db = SQLite.DB()
    backup(new_db, val.db)
    new_associations =
        SupplementalAttributeAssociations(new_db, Dict{String, SQLite.Stmt}())
    dict[val] = new_associations
    return new_associations
end

"""
Add a supplemental attribute association to the associations. The caller must check for
duplicates.
"""
function add_association!(
    associations::SupplementalAttributeAssociations,
    component::InfrastructureSystemsComponent,
    attribute::SupplementalAttribute,
)
    TimerOutputs.@timeit_debug SYSTEM_TIMERS "add supplemental attribute association" begin
        row = (
            string(get_uuid(attribute)),
            string(nameof(typeof(attribute))),
            string(get_uuid(component)),
            string(nameof(typeof(component))),
        )
        params = chop(repeat("?,", length(row)))
        _execute_cached(
            associations,
            "INSERT INTO $SUPPLEMENTAL_ATTRIBUTE_TABLE_NAME VALUES($params)",
            row,
        )
        @debug "Added association bewteen $(summary(attribute)) and $(summary(component))"
        LOG_GROUP_SUPPLEMENTAL_ATTRIBUTES
    end
    return
end

"""
Drop the supplemental attribute associations table.
"""
function drop_table(associations::SupplementalAttributeAssociations)
    _execute(associations, "DROP TABLE IF EXISTS $SUPPLEMENTAL_ATTRIBUTE_TABLE_NAME")
    @debug "Dropped the table $SUPPLEMENTAL_ATTRIBUTE_TABLE_NAME (if it existed)" _group =
        LOG_GROUP_SUPPLEMENTAL_ATTRIBUTES
    return
end

"""
Return a Vector of OrderedDict of stored time series counts by type.
"""
function get_attribute_counts_by_type(associations::SupplementalAttributeAssociations)
    query = """
        SELECT
            attribute_type
            ,count(*) AS count
        FROM $SUPPLEMENTAL_ATTRIBUTE_TABLE_NAME
        GROUP BY
            attribute_type
        ORDER BY
            attribute_type
    """
    table = Tables.rowtable(_execute(associations, query))
    return [
        OrderedDict("type" => x.attribute_type, "count" => x.count) for x in table
    ]
end

"""
Return a DataFrame with the number of supplemental attributes by type for components.
"""
function get_attribute_summary_table(associations::SupplementalAttributeAssociations)
    query = """
        SELECT
            attribute_type
            ,component_type
            ,count(*) AS count
        FROM $SUPPLEMENTAL_ATTRIBUTE_TABLE_NAME
        GROUP BY
            attribute_type
            ,component_type
        ORDER BY
            attribute_type
            ,component_type
    """
    return DataFrame(_execute(associations, query))
end

"""
Return the number of supplemental attributes.
"""
function get_num_attributes(associations::SupplementalAttributeAssociations)
    query = """
        SELECT COUNT(DISTINCT attribute_uuid) AS count
        FROM $SUPPLEMENTAL_ATTRIBUTE_TABLE_NAME
    """
    return _execute_count(associations, query)
end

"""
Return the number of components with supplemental attributes.
"""
function get_num_components_with_attributes(associations::SupplementalAttributeAssociations)
    query = """
        SELECT COUNT(DISTINCT component_uuid) AS count
        FROM $SUPPLEMENTAL_ATTRIBUTE_TABLE_NAME
    """
    return _execute_count(associations, query)
end

const _QUERY_HAS_ASSOCIATION_BY_ATTRIBUTE = """
    SELECT attribute_uuid
    FROM $SUPPLEMENTAL_ATTRIBUTE_TABLE_NAME
    WHERE attribute_uuid = ?
    LIMIT 1
"""

"""
Return true if there is at least one association matching the inputs.
"""
function has_association(
    associations::SupplementalAttributeAssociations,
    attribute::SupplementalAttribute,
)
    # Note: Unlike the other has_association methods, this is not covered by an index.
    params = (string(get_uuid(attribute)),)
    return !isempty(
        Tables.rowtable(
            _execute_cached(associations, _QUERY_HAS_ASSOCIATION_BY_ATTRIBUTE, params),
        ),
    )
end

const _QUERY_HAS_ASSOCIATION_BY_COMPONENT_ATTRIBUTE = """
    SELECT attribute_uuid
    FROM $SUPPLEMENTAL_ATTRIBUTE_TABLE_NAME
    WHERE attribute_uuid = ? AND component_uuid = ?
    LIMIT 1
"""
function has_association(
    associations::SupplementalAttributeAssociations,
    component::InfrastructureSystemsComponent,
    attribute::SupplementalAttribute,
)
    a_uuid = get_uuid(attribute)
    c_uuid = get_uuid(component)
    params = (string(a_uuid), string(c_uuid))
    return !isempty(
        _execute_cached(
            associations,
            _QUERY_HAS_ASSOCIATION_BY_COMPONENT_ATTRIBUTE,
            params,
        ),
    )
end

const _QUERY_HAS_ASSOCIATION_BY_COMPONENT = """
    SELECT attribute_uuid
    FROM $SUPPLEMENTAL_ATTRIBUTE_TABLE_NAME
    WHERE component_uuid = ?
    LIMIT 1
"""
function has_association(
    associations::SupplementalAttributeAssociations,
    component::InfrastructureSystemsComponent,
)
    params = (string(get_uuid(component)),)
    return !isempty(
        Tables.rowtable(
            _execute_cached(associations, _QUERY_HAS_ASSOCIATION_BY_COMPONENT, params),
        ),
    )
end

const _QUERY_HAS_ASSOCIATION_BY_COMP_ATTR_TYPE = """
    SELECT attribute_uuid
    FROM $SUPPLEMENTAL_ATTRIBUTE_TABLE_NAME
    WHERE component_uuid = ? AND attribute_type = ?
    LIMIT 1
"""
function has_association(
    associations::SupplementalAttributeAssociations,
    component::InfrastructureSystemsComponent,
    attribute_type::Type{<:SupplementalAttribute},
)
    params = (string(get_uuid(component)), string(nameof(attribute_type)))
    return !isempty(
        Tables.rowtable(
            _execute_cached(associations, _QUERY_HAS_ASSOCIATION_BY_COMP_ATTR_TYPE, params),
        ),
    )
end

const _QUERY_LIST_ASSOCIATED_COMP_UUIDS = """
    SELECT component_uuid
    FROM $SUPPLEMENTAL_ATTRIBUTE_TABLE_NAME
    WHERE attribute_uuid = ?
"""

"""
Return the component UUIDs associated with the attribute.
"""
function list_associated_component_uuids(
    associations::SupplementalAttributeAssociations,
    attribute::SupplementalAttribute,
)
    params = (string(get_uuid(attribute)),)
    table = Tables.columntable(
        _execute_cached(associations, _QUERY_LIST_ASSOCIATED_COMP_UUIDS, params),
    )
    return Base.UUID.(table.component_uuid)
end

"""
Return the component UUIDs associated with the attribute.
"""
function list_associated_component_uuids(
    associations::SupplementalAttributeAssociations,
    attribute_type::Type{<:SupplementalAttribute},
)
    if isconcretetype(attribute_type)
        return _list_associated_component_uuids(associations, (attribute_type,))
    end

    subtypes = get_all_concrete_subtypes(attribute_type)
    return _list_associated_component_uuids(associations, subtypes)
end

const _QUERY_LIST_ASSOCIATED_COMP_UUIDS_BY_ONE_TYPE = """
    SELECT DISTINCT component_uuid
    FROM $SUPPLEMENTAL_ATTRIBUTE_TABLE_NAME
    WHERE attribute_type = ?
"""

function _list_associated_component_uuids(
    associations::SupplementalAttributeAssociations,
    attribute_types,
)
    len = length(attribute_types)
    if len == 0
        # This would require an abstract type with no subtypes. Just here for completeness.
        return Base.UUID[]
    elseif len == 1
        query = _QUERY_LIST_ASSOCIATED_COMP_UUIDS_BY_ONE_TYPE
        params = (string(nameof(first(attribute_types))),)
    else
        placeholder = chop(repeat("?,", length(attribute_types)))
        params = Tuple(string(nameof(type)) for type in attribute_types)
        query = """
            SELECT DISTINCT component_uuid
            FROM $SUPPLEMENTAL_ATTRIBUTE_TABLE_NAME
            WHERE attribute_type IN ($placeholder)
        """
    end

    table = Tables.columntable(_execute_cached(associations, query, params))
    return Base.UUID.(table.component_uuid)
end

"""
Return the supplemental attribute UUIDs associated with the component and attribute type.
"""
function list_associated_supplemental_attribute_uuids(
    associations::SupplementalAttributeAssociations,
    component::InfrastructureSystemsComponent;
    attribute_type::Union{Nothing, Type{<:SupplementalAttribute}} = nothing,
)
    c_str = "component_uuid = ?"
    params = [string(get_uuid(component))]
    if isnothing(attribute_type)
        where_clause = c_str
    else
        a_str = _get_attribute_type_string!(params, attribute_type)
        where_clause = "$c_str AND $a_str"
    end
    query = """
        SELECT attribute_uuid
        FROM $SUPPLEMENTAL_ATTRIBUTE_TABLE_NAME
        WHERE $where_clause
    """
    table = Tables.columntable(_execute_cached(associations, query, params))
    return Base.UUID.(table.attribute_uuid)
end

"""
Remove the association between the attribute and component.
"""
function remove_association!(
    associations::SupplementalAttributeAssociations,
    component::InfrastructureSystemsComponent,
    attribute::SupplementalAttribute,
)
    where_clause = "WHERE attribute_uuid = ? AND component_uuid = ?"
    params = (string(get_uuid(attribute)), string(get_uuid(component)))
    num_deleted = _remove_associations!(associations, where_clause, params)
    if num_deleted != 1
        error("Bug: unexpected number of deletions: $num_deleted. Should have been 1.")
    end
end

"""
Remove all associations of the given type.
"""
function remove_associations!(
    associations::SupplementalAttributeAssociations,
    type::Type{<:SupplementalAttribute},
)
    where_clause = "WHERE attribute_type = ?"
    params = (string(nameof(type)),)
    num_deleted = _remove_associations!(associations, where_clause, params)
    @debug "Deleted $num_deleted supplemental attribute associations" _group =
        LOG_GROUP_SUPPLEMENTAL_ATTRIBUTES
    return
end

const _QUERY_REPLACE_COMP_UUID_SA = """
    UPDATE $SUPPLEMENTAL_ATTRIBUTE_TABLE_NAME
    SET component_uuid = ?
    WHERE component_uuid = ?
"""

"""
Replace the component UUID in the table.
"""
function replace_component_uuid!(
    associations::SupplementalAttributeAssociations,
    old_uuid::Base.UUID,
    new_uuid::Base.UUID,
)
    params = (string(new_uuid), string(old_uuid))
    _execute_cached(associations, _QUERY_REPLACE_COMP_UUID_SA, params)
    return
end

"""
Run a query and return the results in a DataFrame.
"""
function sql(
    associations::SupplementalAttributeAssociations,
    query::String,
    params = nothing,
)
    return DataFrames.DataFrame(_execute(associations, query, params))
end

"""
Return all rows in the table as dictionaries.
"""
function to_records(associations::SupplementalAttributeAssociations)
    query = "SELECT * FROM $SUPPLEMENTAL_ATTRIBUTE_TABLE_NAME"
    return Tables.rowtable(_execute(associations, query))
end

"""
Add records to the database. Expects output from [`to_records`](@ref).
"""
function from_records(::Type{SupplementalAttributeAssociations}, records)
    associations = SupplementalAttributeAssociations(; create_indexes = false)
    isempty(records) && return associations

    columns = ("attribute_uuid", "attribute_type", "component_uuid", "component_type")
    num_rows = length(records)
    num_columns = length(columns)
    data = OrderedDict(x => Vector{String}(undef, num_rows) for x in columns)
    for (i, record) in enumerate(records)
        for column in columns
            data[column][i] = record[column]
        end
    end
    params = chop(repeat("?,", num_columns))
    SQLite.DBInterface.executemany(
        associations.db,
        "INSERT INTO $SUPPLEMENTAL_ATTRIBUTE_TABLE_NAME VALUES($params)",
        NamedTuple(Symbol(k) => v for (k, v) in data),
    )
    _create_indexes!(associations)
    return associations
end

function _remove_associations!(
    associations::SupplementalAttributeAssociations,
    where_clause::AbstractString,
    params,
)
    _execute_cached(
        associations,
        "DELETE FROM $SUPPLEMENTAL_ATTRIBUTE_TABLE_NAME $where_clause",
        params,
    )
    table = Tables.rowtable(_execute(associations, "SELECT CHANGES() AS changes"))
    @assert_op length(table) == 1
    @debug "Deleted $(table[1].changes) rows from the time series metadata table" _group =
        LOG_GROUP_SUPPLEMENTAL_ATTRIBUTES
    return table[1].changes
end

function compare_values(
    match_fn::Union{Function, Nothing},
    x::SupplementalAttributeAssociations,
    y::SupplementalAttributeAssociations;
    compare_uuids = false,
    exclude = Set{Symbol}(),
)
    !compare_uuids && return true
    query = """
        SELECT *
        FROM $SUPPLEMENTAL_ATTRIBUTE_TABLE_NAME
        ORDER BY attribute_uuid, component_uuid
    """
    table_x = Tables.rowtable(_execute(x, query))
    table_y = Tables.rowtable(_execute(y, query))
    match_fn = _fetch_match_fn(match_fn)
    return match_fn(table_x, table_y)
end

function _make_stmt(associations::SupplementalAttributeAssociations, query::String)
    return get!(
        () -> SQLite.Stmt(associations.db, query),
        associations.cached_statements,
        query,
    )
end

_execute_cached(s::SupplementalAttributeAssociations, q, p = nothing) =
    execute(_make_stmt(s, q), p, LOG_GROUP_TIME_SERIES)
_execute(s::SupplementalAttributeAssociations, q, p = nothing) =
    execute(s.db, q, p, LOG_GROUP_SUPPLEMENTAL_ATTRIBUTES)
_execute_count(s::SupplementalAttributeAssociations, q, p = nothing) =
    execute_count(s.db, q, p, LOG_GROUP_SUPPLEMENTAL_ATTRIBUTES)

function _get_attribute_type_string!(
    params, attribute_type::Union{Nothing, Type{<:SupplementalAttribute}},
)
    val = if isnothing(attribute_type)
        ""
    elseif isabstracttype(attribute_type)
        count = 0
        for type in get_all_concrete_subtypes(attribute_type)
            push!(params, string(nameof(type)))
            count += 1
        end
        placeholder = chop(repeat("?,", count))
        "attribute_type in ($placeholder)"
    else
        push!(params, string(nameof(attribute_type)))
        "attribute_type = ?"
    end

    return val
end
