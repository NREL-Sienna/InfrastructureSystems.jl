"""
Abstract type for time_series that are stored in a system.
Users never create them or get access to them.
Stores references to time series data, so a disk read may be required for access.
"""
abstract type TimeSeriesMetadata <: InfrastructureSystemsType end

"""
Abstract type for time_series supplied to users. They are not stored in a system. Instead,
they are generated on demand for the user.
Users can create them. The system will convert them to a subtype of TimeSeriesMetadata for
storage.
Time series data is stored as a field, so reads will always be from memory.
"""
abstract type AbstractTimeSeriesData <: Any end
