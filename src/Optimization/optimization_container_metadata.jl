const _CONTAINER_METADATA_FILE = "optimization_container_metadata.bin"

struct OptimizationContainerMetadata
    container_key_lookup::Dict{String, <:OptimizationContainerKey}
end

function OptimizationContainerMetadata()
    return OptimizationContainerMetadata(Dict{String, OptimizationContainerKey}())
end

_make_metadata_path(model_name::Symbol, output_dir::String) =
    joinpath(output_dir, string(model_name))
_make_metadata_filename(model_name::Symbol, output_dir::String) =
    joinpath(_make_metadata_path(model_name, output_dir), _CONTAINER_METADATA_FILE)
_make_metadata_filename(output_dir) = joinpath(output_dir, _CONTAINER_METADATA_FILE)

function serialize_metadata(
    output_dir::String,
    metadata::OptimizationContainerMetadata,
    model_name::Symbol,
)
    file_path = _make_metadata_path(model_name, output_dir)
    mkpath(file_path)
    filename = _make_metadata_filename(model_name, output_dir)
    Serialization.serialize(filename, metadata)
    return
end

function deserialize_metadata(
    ::Type{OptimizationContainerMetadata},
    output_dir::String,
    model_name::Symbol,
)
    filename = _make_metadata_filename(model_name, output_dir)
    return Serialization.deserialize(filename)
end

function deserialize_key(metadata::OptimizationContainerMetadata, name::AbstractString)
    !haskey(metadata.container_key_lookup, name) && error("$name is not stored")
    return metadata.container_key_lookup[name]
end

add_container_key!(x::OptimizationContainerMetadata, key::String, val) =
    x.container_key_lookup[key] = val
get_container_key(x::OptimizationContainerMetadata, key::String) =
    x.container_key_lookup[key]
has_container_key(x::OptimizationContainerMetadata, key::String) =
    haskey(x.container_key_lookup, key)
