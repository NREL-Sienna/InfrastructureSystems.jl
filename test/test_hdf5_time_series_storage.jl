
@testset "Test automatic file deletion" begin
    storage = Hdf5TimeSeriesStorage()
    filename = storage.file_path
    @test isfile(filename)
    storage = nothing
    GC.gc()
    @test !isfile(filename)
end
