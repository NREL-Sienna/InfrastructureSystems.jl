# TODO add a kwarg and testing for filtering on is_available

# ABSTRACT TYPE DEFINITIONS
"""The basic type for all ComponentSelectors.

Concrete subtypes MUST implement:
 - `get_components`
 - `get_name`, or use the default by implementing `default_name` and having a `name` field

Concrete subtypes MAY implement:
 - The factory method `select_components` (make sure your signature does not conflict with
   an existing one)
 - `default_name`
"""
abstract type ComponentSelector end

"""
ComponentSelectors that are not composed of other ComponentSelectors.

The interface is the same as for `ComponentSelector` except `get_components` MUST return
zero or one components
"""
abstract type ComponentSelectorElement <: ComponentSelector end

"""
ComponentSelectors that are composed of other ComponentSelectors.

The interface is that of `ComponentSelector` plus concrete subtypes MUST implement
`get_subselectors`
"""
abstract type ComponentSelectorSet <: ComponentSelector end

# COMMON COMPONENTSELECTOR INFRASTRUCTURE
# TODO perhaps put this elsewhere; it is also referenced in metrics.jl
"Delimeter to use when constructing fully-qualified names."
const NAME_DELIMETER::String = "__"

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
) = subtype_to_string(component_subtype) * NAME_DELIMETER * component_name
component_to_qualified_string(component::InfrastructureSystemsComponent) =
    component_to_qualified_string(typeof(component), get_name(component))

# Generic implementations/generic docstrings for simple functions with many methods
"""
Get the default name for the ComponentSelector, constructed automatically from what the
ComponentSelector contains. Particularly with complex ComponentSelectors, this may not
always be very concise or informative, so in these cases constructing the ComponentSelector
with a custom name is recommended.
"""
function default_name end

"""
Get the name of the ComponentSelector. This is either the default name or a custom name passed in at
creation time.
"""
# Override this if you define a ComponentSelector subtype with no name field
get_name(e::ComponentSelector) = (e.name !== nothing) ? e.name : default_name(e)

# Make all get_components, get_subselectors below that take a Components also work with a SystemData
"""
Get the components of the collection that make up the ComponentSelector.
"""
get_components(e::ComponentSelector, sys::SystemData) = get_components(e, sys.components)

"""
Get the sub-selectors that make up the ComponentSelectorSet.
"""
get_subselectors(e::ComponentSelectorSet, sys::SystemData) =
    get_subselectors(e, sys.components)

# CONCRETE SUBTYPE IMPLEMENTATIONS
# SingleComponentSelector
"ComponentSelector that wraps a single Component."
struct SingleComponentSelector <: ComponentSelectorElement
    component_subtype::Type{<:InfrastructureSystemsComponent}
    component_name::AbstractString
    name::Union{String, Nothing}
end

# Construction
"""
Make a ComponentSelector pointing to an InfrastructureSystemsComponent with the given
subtype and name. Optionally provide a name for the ComponentSelector.
"""
select_components(
    component_subtype::Type{<:InfrastructureSystemsComponent},
    component_name::AbstractString,
    name::Union{String, Nothing} = nothing,
) = SingleComponentSelector(component_subtype, component_name, name)
"""
Construct a ComponentSelector from an InfrastructureSystemsComponent reference, pointing to Components in any
collection with the given Component's subtype and name.
"""
select_components(
    component_ref::InfrastructureSystemsComponent,
    name::Union{String, Nothing} = nothing,
) =
    select_components(typeof(component_ref), get_name(component_ref), name)

# Naming
default_name(e::SingleComponentSelector) =
    component_to_qualified_string(e.component_subtype, e.component_name)

# Contents
function get_components(e::SingleComponentSelector, sys::Components)
    com = get_component(e.component_subtype, sys, e.component_name)
    return (com === nothing) ? [] : [com]
end

# ListComponentSelector
"ComponentSelectorSet represented by a list of other ComponentSelectors."
struct ListComponentSelector <: ComponentSelectorSet
    # Using tuples internally for immutability => `==` is automatically well-behaved
    content::Tuple{Vararg{ComponentSelector}}
    name::Union{String, Nothing}
end

# Construction
"""
Make a ComponentSelector pointing to a list of subselectors. Optionally provide a name for
the ComponentSelector.
"""
# name needs to be a kwarg to disambiguate from content
select_components(content::ComponentSelector...; name::Union{String, Nothing} = nothing) =
    ListComponentSelector(content, name)

# Naming
default_name(e::ListComponentSelector) = "[$(join(get_name.(e.content), ", "))]"

# Contents
function get_subselectors(e::ListComponentSelector, sys::Components)
    return e.content
end

function get_components(e::ListComponentSelector, sys::Components)
    sub_components = Iterators.map(x -> get_components(x, sys), e.content)
    return Iterators.flatten(sub_components)
end

# SubtypeComponentSelector
"ComponentSelectorSet represented by a subtype of Component."
struct SubtypeComponentSelector <: ComponentSelectorSet
    component_subtype::Type{<:InfrastructureSystemsComponent}
    name::Union{String, Nothing}
end

# Construction
"""
Make a ComponentSelector from a subtype of Component. Optionally provide a name for the
ComponentSelectorSet.
"""
# name needs to be a kwarg to disambiguate from SingleComponentSelector's select_components
select_components(
    component_subtype::Type{<:InfrastructureSystemsComponent};
    name::Union{String, Nothing} = nothing,
) =
    SubtypeComponentSelector(component_subtype, name)

# Naming
default_name(e::SubtypeComponentSelector) = subtype_to_string(e.component_subtype)

# Contents
function get_subselectors(e::SubtypeComponentSelector, sys::Components)
    return Iterators.map(select_components, get_components(e, sys))
end

function get_components(e::SubtypeComponentSelector, sys::Components)
    return get_components(e.component_subtype, sys)
end

# FilterComponentSelector
"ComponentSelectorSet represented by a filter function and a subtype of Component."
struct FilterComponentSelector <: ComponentSelectorSet
    filter_fn::Function
    component_subtype::Type{<:InfrastructureSystemsComponent}
    name::Union{String, Nothing}
end

# Construction
"""
Make a ComponentSelector from a filter function and a subtype of Component. Optionally
provide a name for the ComponentSelector. The filter function must accept instances of
component_subtype as a sole argument and return a Bool.
"""
function select_components(
    filter_fn::Function,
    component_subtype::Type{<:InfrastructureSystemsComponent},
    name::Union{String, Nothing} = nothing,
)
    # Try to catch inappropriate filter functions
    hasmethod(filter_fn, Tuple{component_subtype}) || throw(
        ArgumentError(
            "filter function $filter_fn does not have a method that accepts $(subtype_to_string(component_subtype)).",
        ),
    )
    # TODO it would be nice to have more rigorous checks on filter_fn here: check that the
    # return type is a Bool and check whether a filter_fn without parameter type annotations
    # can in fact be called on the given subtype (e.g., filter_fn = (x -> x+1 == 0) should
    # fail). Core.compiler.return_type does not seem to be stable enough to rely on. The
    # IsDef.jl library looks interesting.
    return FilterComponentSelector(filter_fn, component_subtype, name)
end

# Contents
function get_subselectors(e::FilterComponentSelector, sys::Components)
    return Iterators.map(select_components, get_components(e, sys))
end

function get_components(e::FilterComponentSelector, sys::Components)
    return get_components(e.filter_fn, e.component_subtype, sys)
end

# Naming
default_name(e::FilterComponentSelector) =
    string(e.filter_fn) * NAME_DELIMETER * subtype_to_string(e.component_subtype)
