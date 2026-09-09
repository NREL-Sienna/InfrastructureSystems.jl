# The Sienna archive: a directory of files, zipped into one `.sn`.
#
# The container only — nothing here knows what the members are. A package decides that: a
# PowerSystems archive holds a system document plus its time-series sidecars, a portfolio
# archive holds whatever a portfolio needs. What is shared, and what lives here, is the
# extension the format is recognized by, the guards a write has to pass, and the compression
# itself.

"""Extension a Sienna archive is recognized by, on write and on read."""
const SIENNA_ARCHIVE_EXTENSION = ".sn"

"""HDF5 is already compressed."""
const NO_COMPRESS_EXTENSIONS = (".h5", ".hdf5")

"""
$(TYPEDSIGNATURES)

Whether `path` names a Sienna archive, by its extension.

The extension is the whole test: a reader picks the archive path over the directory path from
this, so a writer is held to it too (see [`create_sienna_archive`](@ref)).
"""
is_sienna_archive(path::AbstractString) =
    lowercase(splitext(path)[2]) == SIENNA_ARCHIVE_EXTENSION

_should_compress_member(name::AbstractString) =
    lowercase(splitext(name)[2]) ∉ NO_COMPRESS_EXTENSIONS

"""Write one member, named by its path relative to the staging directory."""
function _add_archive_member!(
    archive::ZipArchives.ZipWriter,
    file::AbstractString,
    staging::AbstractString,
)
    name = join(splitpath(relpath(file, staging)), "/")
    ZipArchives.zip_newfile(archive, name; compress = _should_compress_member(name))
    open(file, "r") do io
        write(archive, io)
    end
    return nothing
end

"""
$(TYPEDSIGNATURES)

Archive a directory into the single zip archive at `path`, calling `fill!` to populate it.

`fill!` receives a staging directory that does not yet exist and writes the archive's members
into it; every file in it afterwards becomes a member. The staging directory is temporary and
its name never reaches the archive — members are named by their path relative to it, so they
sit at the archive root rather than under a prefix. Empty directories are not members.

Members are deflated except for the extensions in [`NO_COMPRESS_EXTENSIONS`](@ref),
which are stored as they are.

Refuses, before calling `fill!`, a `path` that is not `$SIENNA_ARCHIVE_EXTENSION` (the reader
recognizes the format by extension, so a differently named archive could not be read back), a
`path` that is a directory, and an existing file unless `force`.

```julia
create_sienna_archive(joinpath(dir, "case.sn"); force = true) do staging
    write_my_document(joinpath(staging, "portfolio.json"))
end
```
"""
function create_sienna_archive(fill!::Function, path::AbstractString; force::Bool = false)
    if !is_sienna_archive(path)
        throw(
            DataFormatError(
                "$path does not end in $SIENNA_ARCHIVE_EXTENSION; a Sienna archive requires " *
                "that extension so it can be recognized on read.",
            ),
        )
    end
    if isdir(path)
        throw(DataFormatError("$path is a directory; a Sienna archive is a single file"))
    end
    if isfile(path) && !force
        throw(
            DataFormatError(
                "$path already exists; pass force = true to overwrite the archive",
            ),
        )
    end
    mkpath(dirname(path))
    mktempdir() do dir
        staging = joinpath(dir, "archive")
        fill!(staging)
        ZipArchives.ZipWriter(path) do archive
            for (root, _, files) in walkdir(staging)
                for file in files
                    _add_archive_member!(archive, joinpath(root, file), staging)
                end
            end
        end
    end
    return nothing
end

function _extract_archive_member(
    archive::ZipArchives.ZipReader,
    i::Int,
    dir::AbstractString,
)
    name = ZipArchives.zip_name(archive, i)
    if isabspath(name) || ".." in splitpath(name)
        throw(
            DataFormatError(
                "archive member \"$name\" points outside the archive; refusing to extract it",
            ),
        )
    end
    destination = joinpath(dir, name)
    if endswith(name, "/")
        mkpath(destination)
        return nothing
    end
    mkpath(dirname(destination))
    ZipArchives.zip_openentry(archive, i) do member
        open(destination, "w") do io
            write(io, member)
        end
    end
    return nothing
end

"""
$(TYPEDSIGNATURES)

Extract the Sienna archive at `path` and return the directory holding its members.

The directory lives for the rest of the session rather than the rest of this call.
`mktempdir()`'s default `cleanup = true` registers it for deletion at exit, which is what a
caller that keeps reading from the extracted files needs — a store opened in place out of the
archive, say — while still not leaking into the OS temp root permanently.
"""
function extract_sienna_archive(path::AbstractString)
    if !isfile(path)
        throw(DataFormatError("$path does not exist"))
    end
    dir = mktempdir()
    open(path, "r") do io
        archive = ZipArchives.ZipReader(Mmap.mmap(io))
        for i in 1:ZipArchives.zip_nentries(archive)
            _extract_archive_member(archive, i, dir)
        end
    end
    return dir
end
