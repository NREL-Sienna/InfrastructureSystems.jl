# Component Time Series Data

`InfrastructureSystems.jl` implements containers and routines to efficiently manage time
series data. This document contains content for developers of new time series data. For the
usage please refer to the documentation in [PowerSystems.jl](https://nrel-siip.github.io/PowerSystems.jl/stable)

`InfrastructureSystems.jl` provides a mechanism to store time series data for
components. Here are reasons to consider using it:

- Time series data, by default, is stored independently of components in HDF5 files.
Components store references to that data.
- System memory is not depleted by loading all time series data at once. Only data that you
need is loaded.
- Multiple components can share the same time series data by sharing references instead of
making expensive copies.
- Supports serialization and deserialization.
- Supports parsing raw data files of several formats as well as data stored in
  `TimeSeries.TimeArray` and `DataFrames.DataFrame` objects.

If you store an instance of `SystemData` within your system and then a user
calls `deepcopy` on a system, the .h5 file will not be copied. The new and
old instances will have references to the same file. You will need to
reimplement `deepcopy` to handle this. One solution is to serialize and then
deserialize the system. **You must reimplement deepcopy if you use HDF5**

*Notes*:

- Time series data can optionally be stored fully in memory. Refer to the
[`InfrastructureSystems.SystemData`](@ref) documentation.
- `InfrastructureSystems.jl` creates HDF5 files on the tmp filesystem by default.
  This can be changed if the time series data is larger than the amount of
  tmp space available. Refer to the [`InfrastructureSystems.SystemData`](@ref) link above.

## Instructions

1. Add an instance of `InfrastructureSystems.TimeSeriesContainer` to the component struct.
2. Implement the method `InfrastructureSystems.get_time_series_container` for the
   component. It must return the TimeSeriesContainer object.
