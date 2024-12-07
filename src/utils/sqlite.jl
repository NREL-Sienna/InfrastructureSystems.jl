"""
Backup a SQLite database.
"""
# This has been proposed as a solution to https://github.com/JuliaDatabases/SQLite.jl/issues/210
# and will be removed when the functionality is part of SQLite.jl.
function backup(
    dst::SQLite.DB,
    src::SQLite.DB;
    dst_name::AbstractString = "main",
    src_name::AbstractString = "main",
    pages::Int = -1,
    sleep::Float64 = 0.25,
)
    if src === dst
        error("src and dst cannot be the same connection")
    end

    C = SQLite.C
    num_pages = pages == 0 ? -1 : pages
    sleep_ms = sleep * 1000
    ptr = C.sqlite3_backup_init(dst.handle, dst_name, src.handle, src_name)
    r = C.SQLITE_OK
    try
        while r == C.SQLITE_OK || r == C.SQLITE_BUSY || r == C.SQLITE_LOCKED
            r = C.sqlite3_backup_step(ptr, num_pages)
            @debug "backup iteration: remaining = $(C.sqlite3_backup_remaining(ptr))"
            if r == C.SQLITE_BUSY || r == C.SQLITE_LOCKED
                C.sqlite3_sleep(sleep_ms)
            end
        end
    finally
        C.sqlite3_backup_finish(ptr)
        if r != C.SQLITE_DONE
            e = SQLite.sqliteexception(src.handle)
            C.sqlite3_reset(src.handle)
            throw(e)
        end
    end
end

const STATEMENT_CACHE = Dict{String, SQLite.Stmt}()

"""
Wrapper around SQLite.DBInterface.execute to provide caching of compiled statements
as well as log messages.
"""
function execute(
    db::SQLite.DB,
    query::AbstractString,
    params::Union{Nothing, Vector},
    log_group::Symbol,
)
    @debug "Execute SQL" _group = log_group query params
    try
        return if isnothing(params)
            SQLite.DBInterface.execute(db, query)
        else
            SQLite.DBInterface.execute(db, query, params)
        end
    catch
        @error "Failed to send SQL query" query params
        rethrow()
    end
end

function execute(
    stmt::SQLite.Stmt,
    params::Union{Nothing, Vector, Tuple},
    log_group::Symbol,
)
    @debug "Execute SQL" _group = log_group params
    try
        return if isnothing(params)
            SQLite.DBInterface.execute(stmt)
        else
            SQLite.DBInterface.execute(stmt, params)
        end
    catch
        @error "Failed to send SQL query" params
        rethrow()
    end
end

"""
Run a query to find a count. The query must produce a column called count with one row.
"""
function execute_count(
    db::SQLite.DB,
    query::AbstractString,
    params::Union{Nothing, Vector},
    log_group::Symbol,
)
    for row in Tables.rows(execute(db, query, params, log_group))
        return row.count
    end

    error("Bug: unexpectedly did not receive any rows")
end
