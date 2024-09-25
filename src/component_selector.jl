# ABSTRACT TYPE DEFINITIONS
"""The basic type for all `ComponentSelector`s.

Concrete subtypes MUST implement:
 - `get_components`: returns an iterable of components
 - `get_name`: returns a name for the selector -- or use the default by implementing `default_name` and having a `name` field
 - `get_groups`: returns an iterable of `ComponentSelector`s

Concrete subtypes MAY implement:
 - The factory method `make_selector` (make sure your signature does not conflict with
   an existing one)
 - `default_name`
"""
abstract type ComponentSelector end

"""
`ComponentSelector`s that can only refer to zero or one components.

The interface is the same as for `ComponentSelector` except
 - `get_components` MUST return zero or one components
 - the additional method `get_component` is part of the interface, but the default
   implementation just wraps `get_components` and should not need to be overridden.
 - there is a sensible default for `get_groups`
"""
abstract type SingularComponentSelector <: ComponentSelector end

"""
`ComponentSelector`s that may refer to multiple components.

The interface is that of `ComponentSelector`.
"""
abstract type PluralComponentSelector <: ComponentSelector end

"""
`PluralComponentSelector`s whose grouping is determined by a `groupby` field (all of the
built-in `PluralComponentSelector`s except `ListComponentSelector` work this way)
"""
abstract type DynamicallyGroupedPluralComponentSelector <: PluralComponentSelector end

# COMMON COMPONENTSELECTOR INFRASTRUCTURE
"Canonical way to turn an InfrastructureSystemsComponent subtype into a unique string."
subtype_to_string(subtype::Type{<:InfrastructureSystemsComponent}) =
    strip_module_name(subtype)

"""
Canonical way to turn an InfrastructureSystemsComponent specification/instance into a
unique-per-container string.
"""
component_to_qualified_string(
    component_subtype::Type{<:InfrastructureSystemsComponent},
    component_name::AbstractString,
) = subtype_to_string(component_subtype) * COMPONENT_NAME_DELIMETER * component_name
component_to_qualified_string(component::InfrastructureSystemsComponent) =
    component_to_qualified_string(typeof(component), get_name(component))

const VALID_GROUPBY_KEYWORDS = [:all, :each]

"""
Helper function to check that the `groupby` argument is valid. Passes it through if so,
errors if not.
"""
validate_groupby(groupby::Symbol) =
    if (groupby in VALID_GROUPBY_KEYWORDS)
        groupby
    else
        throw(ArgumentError("groupby must be one of $VALID_GROUPBY_KEYWORDS or a function"))
    end
validate_groupby(groupby::Function) = groupby  # Don't try to validate functions for now

# Generic implementations/generic docstrings for simple functions with many methods
"""
Get the default name for the `ComponentSelector`, constructed automatically from what the
`ComponentSelector` contains. Particularly with complex `ComponentSelector`s, this may not
always be very concise or informative, so in these cases constructing the
`ComponentSelector` with a custom name is recommended.
"""
function default_name end

# Override this if you define a ComponentSelector subtype with no name field
"""
Get the name of the `ComponentSelector`. This is either the default name or a custom name
passed in at creation time.
"""
get_name(e::ComponentSelector) = (e.name !== nothing) ? e.name : default_name(e)

# Make all get_components below that take a Components also work with a SystemData
"""
Get the components of the collection that make up the `ComponentSelector`.
"""
get_components(e::ComponentSelector, sys::SystemData; filterby = nothing) =
    get_components(e, sys.components; filterby = filterby)

"""
Get the component of the collection that makes up the `SingularComponentSelector`; `nothing`
if there is none.
"""
get_component(e::SingularComponentSelector, sys::SystemData; filterby = nothing) =
    get_component(e, sys.components; filterby = filterby)

"""
Get the groups that make up the `ComponentSelector`.
"""
get_groups(e::ComponentSelector, sys::SystemData; filterby = nothing) =
    get_groups(e, sys.components; filterby = filterby)

"""
Use the `groupby` property to get the groups that make up the
`DynamicallyGroupedPluralComponentSelector`
"""
function get_groups(
    e::DynamicallyGroupedPluralComponentSelector,
    sys::Components;
    filterby = nothing,
)
    validate_groupby(e.groupby)
    (e.groupby == :all) && return [e]
    (e.groupby == :each) &&
        return Iterators.map(make_selector, get_components(e, sys; filterby = filterby))
    @assert e.groupby isa Function
    components = collect(get_components(e, sys; filterby = filterby))

    partition_results = (e.groupby).(components)
    unique_partitions = unique(partition_results)
    partition_labels = string.(unique_partitions)
    # Catch the case where `p1 != p2` but `string(p1) == string(p2)`
    (length(unique_partitions) == length(unique(partition_labels))) ||
        throw(ArgumentError("Some partitions have the same name when converted to string"))

    return [
        make_selector(
            make_selector.(components[partition_results .== Ref(group_result)])...;
            name = group_name,
        ) for (group_result, group_name) in zip(unique_partitions, partition_labels)
    ]
end

"Get the single group that corresponds to the `SingularComponentSelector`, i.e., itself"
get_groups(e::SingularComponentSelector, sys::Components; filterby = nothing) = [e]

"""
Get the component of the collection that makes up the `SingularComponentSelector`; `nothing`
if there is none.
"""
function get_component(e::SingularComponentSelector, sys::Components; filterby = nothing)
    components = get_components(e, sys; filterby = filterby)
    isempty(components) && return nothing
    return only(components)
end

# CONCRETE SUBTYPE IMPLEMENTATIONS
# NameComponentSelector
"`ComponentSelector` that refers by name to at most a single component."
struct NameComponentSelector <: SingularComponentSelector
    component_subtype::Type{<:InfrastructureSystemsComponent}
    component_name::AbstractString
    name::Union{String, Nothing}
end

# Construction
"""
Make a `ComponentSelector` pointing to a component with the given subtype and name.
Optionally provide a name for the `ComponentSelector`.
"""
make_selector(
    component_subtype::Type{<:InfrastructureSystemsComponent},
    component_name::AbstractString;
    name::Union{String, Nothing} = nothing,
) = NameComponentSelector(component_subtype, component_name, name)
"""
Make a `ComponentSelector` from a component reference, pointing to components in any
collection with the given component's subtype and name. Optionally provide a name for the
`ComponentSelector`.
"""
make_selector(
    component_ref::InfrastructureSystemsComponent;
    name::Union{String, Nothing} = nothing,
) =
    make_selector(typeof(component_ref), get_name(component_ref); name = name)

# Naming
default_name(e::NameComponentSelector) =
    component_to_qualified_string(e.component_subtype, e.component_name)

# Contents
function get_components(e::NameComponentSelector, sys::Components; filterby = nothing)
    com = get_component(e.component_subtype, sys, e.component_name)
    (!isnothing(filterby) && !filterby(com)) && (com = nothing)
    return (com === nothing) ? [] : [com]
end

# ListComponentSelector
"`PluralComponentSelector` represented by a list of other `ComponentSelector`s."
struct ListComponentSelector <: PluralComponentSelector
    # Using tuples internally for immutability => `==` is automatically well-behaved
    content::Tuple{Vararg{ComponentSelector}}
    name::Union{String, Nothing}
end

# Construction
"""
Make a `ComponentSelector` pointing to a list of sub-selectors, which form the groups.
Optionally provide a name for the `ComponentSelector`.
"""
make_selector(content::ComponentSelector...; name::Union{String, Nothing} = nothing) =
    ListComponentSelector(content, name)

# Naming
default_name(e::ListComponentSelector) = "[$(join(get_name.(e.content), ", "))]"

# Contents
function get_groups(e::ListComponentSelector, sys::Components; filterby = nothing)
    return e.content
end

function get_components(e::ListComponentSelector, sys::Components; filterby = nothing)
    sub_components =
        Iterators.map(x -> get_components(x, sys; filterby = filterby), e.content)
    return Iterators.flatten(sub_components)
end

# SubtypeComponentSelector
"`PluralComponentSelector` represented by a type of component."
struct SubtypeComponentSelector <: DynamicallyGroupedPluralComponentSelector
    component_subtype::Type{<:InfrastructureSystemsComponent}
    name::Union{String, Nothing}
    groupby::Union{Symbol, Function}
end

# Construction
"""
Make a `ComponentSelector` from a type of component. Optionally provide a name for the
`ComponentSelector`.
"""
make_selector(
    component_subtype::Type{<:InfrastructureSystemsComponent};
    name::Union{String, Nothing} = nothing,
    groupby::Union{Symbol, Function} = :all,
) =
    SubtypeComponentSelector(component_subtype, name, validate_groupby(groupby))

# Naming
default_name(e::SubtypeComponentSelector) = subtype_to_string(e.component_subtype)

# Contents
function get_components(e::SubtypeComponentSelector, sys::Components; filterby = nothing)
    components = get_components(e.component_subtype, sys)
    isnothing(filterby) && (return components)
    return Iterators.filter(filterby, components)
end

# FilterComponentSelector
"`PluralComponentSelector` represented by a filter function and a type of component."
struct FilterComponentSelector <: DynamicallyGroupedPluralComponentSelector
    component_subtype::Type{<:InfrastructureSystemsComponent}
    filter_fn::Function
    name::Union{String, Nothing}
    groupby::Union{Symbol, Function}
end

# Construction
# Could try to validate filter_fn here, probably not worth it
"""
Make a ComponentSelector from a filter function and a type of component. Optionally
provide a name for the ComponentSelector. The filter function must accept instances of
component_subtype as a sole argument and return a Bool.
"""
make_selector(
    component_subtype::Type{<:InfrastructureSystemsComponent},
    filter_fn::Function; name::Union{String, Nothing} = nothing,
    groupby::Union{Symbol, Function} = :all,
) = FilterComponentSelector(component_subtype, filter_fn, name, validate_groupby(groupby))

# Contents
function get_components(e::FilterComponentSelector, sys::Components; filterby = nothing)
    components = get_components(e.filter_fn, e.component_subtype, sys)
    isnothing(filterby) && (return components)
    return Iterators.filter(filterby, components)
end

# Naming
default_name(e::FilterComponentSelector) =
    string(e.filter_fn) * COMPONENT_NAME_DELIMETER * subtype_to_string(e.component_subtype)
