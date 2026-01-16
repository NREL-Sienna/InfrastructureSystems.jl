import InfrastructureSystems.Optimization:
    VariableKey,
    OptimizationContainerMetadata,
    encode_key_as_string

@testset "Testset Optimization Container Metadata" begin
    metadata = OptimizationContainerMetadata()
    var_key = VariableKey(MockVariable, IS.TestComponent)
    IS.Optimization.add_container_key!(metadata, encode_key_as_string(var_key), var_key)
    @test IS.Optimization.has_container_key(metadata, encode_key_as_string(var_key))
    @test IS.Optimization.get_container_key(metadata, encode_key_as_string(var_key)) ==
          var_key
    file_dir = mktempdir()
    model_name = :MockModel
    IS.Optimization.serialize_metadata(file_dir, metadata, model_name)
    file_path = IS.Optimization._make_metadata_filename(model_name, file_dir)
    deserialized_metadata = IS.Optimization.deserialize_metadata(
        OptimizationContainerMetadata,
        file_dir,
        model_name,
    )
    @test IS.Optimization.has_container_key(
        deserialized_metadata,
        encode_key_as_string(var_key),
    )
    key = IS.Optimization.deserialize_key(
        metadata,
        "MockVariable__TestComponent",
    )
    @test key == var_key
end
