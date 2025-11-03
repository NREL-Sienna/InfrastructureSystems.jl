"""
    GeographicInfo <: SupplementalAttribute

Supplemental attribute to store geographic information about system components in GeoJSON format.

# Arguments
 - `geo_json::Dict{String, Any}`: dictionary containing GeoJSON data representing the geographic
   information of the component
 - `internal::InfrastructureSystemsInternal`: internal infrastructure systems data for managing
   metadata and UUID tracking
"""
struct GeographicInfo <: SupplementalAttribute
    geo_json::Dict{String, Any}
    internal::InfrastructureSystemsInternal
end

"""
    GeographicInfo(; geo_json, internal)

Construct a GeographicInfo supplemental attribute.

# Arguments
 - `geo_json::Dict{String, <:Any}`: dictionary containing GeoJSON data. Defaults to an empty
   dictionary if not provided
 - `internal::InfrastructureSystemsInternal`: internal infrastructure systems data. Defaults to
   a new InfrastructureSystemsInternal instance if not provided

# Returns
 - `GeographicInfo`: a new GeographicInfo instance

# Example
```julia
# Create with default empty geo_json
geo_info = GeographicInfo()

# Create with specific geo_json data
geo_data = Dict("type" => "Point", "coordinates" => [1.0, 2.0])
geo_info = GeographicInfo(geo_json = geo_data)
```
"""
function GeographicInfo(;
    geo_json::Dict{String, <:Any} = Dict{String, Any}(),
    internal = InfrastructureSystemsInternal(),
)
    return GeographicInfo(geo_json, internal)
end

"""
    get_geo_json(geo::GeographicInfo)

Get the GeoJSON dictionary from a GeographicInfo attribute.

# Arguments
 - `geo::GeographicInfo`: the GeographicInfo attribute

# Returns
 - `Dict{String, Any}`: the GeoJSON dictionary
"""
get_geo_json(geo::GeographicInfo) = geo.geo_json

"""
    get_internal(geo::GeographicInfo)

Get the internal infrastructure systems data from a GeographicInfo attribute.

# Arguments
 - `geo::GeographicInfo`: the GeographicInfo attribute

# Returns
 - `InfrastructureSystemsInternal`: the internal infrastructure systems data
"""
get_internal(geo::GeographicInfo) = geo.internal

"""
    get_uuid(geo::GeographicInfo)

Get the UUID from a GeographicInfo attribute.

# Arguments
 - `geo::GeographicInfo`: the GeographicInfo attribute

# Returns
 - `UUIDs.UUID`: the UUID of the GeographicInfo attribute
"""
get_uuid(geo::GeographicInfo) = get_uuid(get_internal(geo))
