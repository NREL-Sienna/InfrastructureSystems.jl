# ABSTRACT TYPE DEFINITIONS
#=
`ComponentSelector` extension notes:
Concrete subtypes MUST implement:
 - `get_components`: returns an iterable of components
 - `get_name`: returns a name for the selector -- or use the default by implementing
   `default_name` and having a `name` field
 - `get_groups`: returns an iterable of `ComponentSelector`s

Concrete subtypes SHOULD implement:
 - The factory method `make_selector` (make sure your signature does not conflict with an
   existing one)

Concrete subtypes MAY implement:
 - `default_name`
=#
"The base type for all `ComponentSelector`s."
abstract type ComponentSelector end

#=
`SingularComponentSelector` extension notes:
The interface is the same as for `ComponentSelector` except:
 - `get_components` MUST return zero or one components
 - the additional method `get_component` is part of the interface, but the default
   implementation just wraps `get_components` and SHOULD NOT need to be overridden
 - there is a sensible default for `get_groups`; it MAY be overridden
=#
"`ComponentSelector`s that can only refer to zero or one components."
abstract type SingularComponentSelector <: ComponentSelector end

#=
`PluralComponentSelector` extension notes:
The interface is the same as for `ComponentSelector`.
=#
"""`ComponentSelector`s that may refer to multiple components."""
abstract type PluralComponentSelector <: ComponentSelector end

#=
`DynamicallyGroupedComponentSelector` extension notes:
One MAY subtype this and have a `groupby::Union{Symbol, Function}` field to get an automatic
implementation of `get_groups`.
=#
"`PluralComponentSelector`s whose grouping is determined by a `groupby` field."
abstract type DynamicallyGroupedComponentSelector <: PluralComponentSelector end

# COMMON COMPONENTSELECTOR INFRASTRUCTURE
"Canonical way to turn an `InfrastructureSystemsComponent` subtype into a unique string."
subtype_to_string(subtype::Type{<:InfrastructureSystemsComponent}) =
    strip_module_name(subtype)

"""
Canonical way to turn an `InfrastructureSystemsComponent` specification/instance into a
unique-per-system string.
"""
component_to_qualified_string(
    component_type::Type{<:InfrastructureSystemsComponent},
    component_name::AbstractString,
) = subtype_to_string(component_type) * COMPONENT_NAME_DELIMITER * component_name
component_to_qualified_string(component::InfrastructureSystemsComponent) =
    component_to_qualified_string(typeof(component), get_name(component))

const VALID_GROUPBY_KEYWORDS = [:all, :each]

# Ideally we could leave system-like arguments untyped for maximum extensibility, but
# because only PSY.get_components, not IS.get_components, is defined for PSY.System, we need
# to be able to easily override these methods. See
# https://github.com/NREL-Sienna/InfrastructureSystems.jl/issues/388
const SystemLike = Union{Components, SystemData}

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
Factory function to create the appropriate subtype of `ComponentSelector` given the
arguments. Users should call this rather than manually constructing `ComponentSelector`
subtypes.
"""
function make_selector end

"""
Get the default name for the `ComponentSelector`, constructed automatically from what the
`ComponentSelector` contains. Particularly for complex `ComponentSelector`s, this may not
always be very concise or informative, so in these cases constructing the
`ComponentSelector` with a custom name is recommended.
"""
function default_name end

# Override this if you define a ComponentSelector subtype with no name field
"""
Get the name of the `ComponentSelector`. This is either the default name or a custom name
passed in at creation time.
"""
get_name(selector::ComponentSelector) =
    (selector.name !== nothing) ? selector.name : default_name(selector)

"""
    get_components(selector, sys; scope_limiter = nothing)
Get the components of the collection that make up the `ComponentSelector`.
 - `scope_limiter`: optional filter function to limit the scope of components under consideration
"""
function get_components end

"""
    get_components(scope_limiter, selector, sys)
Get the components of the collection that make up the `ComponentSelector`.
 - `scope_limiter`: optional filter function to limit the scope of components under consideration
"""
get_components(
    scope_limiter::Union{Nothing, Function},
    selector::ComponentSelector,
    sys::SystemLike,
) =
    get_components(selector, sys; scope_limiter = scope_limiter)

"""
    get_groups(selector, sys; scope_limiter = nothing)
Get the groups that make up the `ComponentSelector`.
 - `scope_limiter`: optional filter function to limit the scope of components under consideration
"""
function get_groups end

"""
    get_groups(scope_limiter, selector, sys)
Get the groups that make up the `ComponentSelector`.
 - `scope_limiter`: optional filter function to limit the scope of components under consideration
"""
get_groups(
    scope_limiter::Union{Nothing, Function},
    selector::ComponentSelector,
    sys::SystemLike,
) =
    get_groups(selector, sys; scope_limiter = scope_limiter)

"""
Make a `ComponentSelector` containing the components in `all_components` whose corresponding
entry of `partition_results` matches `group_result`
"""
function _make_group(all_components, partition_results, group_result, group_name)
    to_include = [isequal(p_res, group_result) for p_res in partition_results]
    component_selectors = make_selector.(all_components[to_include])
    return make_selector(component_selectors...; name = group_name)
end

"""
Use the `groupby` property to get the groups that make up the
`DynamicallyGroupedComponentSelector`
"""
function get_groups(
    selector::DynamicallyGroupedComponentSelector,
    sys;
    scope_limiter = nothing,
)
    validate_groupby(selector.groupby)
    (selector.groupby == :all) && return [selector]
    (selector.groupby == :each) &&
        return Iterators.map(make_selector,
            get_components(selector, sys; scope_limiter = scope_limiter))
    @assert selector.groupby isa Function
    components = collect(get_components(selector, sys; scope_limiter = scope_limiter))

    partition_results = (selector.groupby).(components)
    unique_partitions = unique(partition_results)
    partition_labels = string.(unique_partitions)
    # Catch the case where `p1 != p2` but `string(p1) == string(p2)`
    (length(unique_partitions) == length(unique(partition_labels))) ||
        throw(ArgumentError("Some partitions have the same name when converted to string"))

    return [
        _make_group(components, partition_results, group_result, group_name)
        for (group_result, group_name) in zip(unique_partitions, partition_labels)
    ]
end

"Get the single group that corresponds to the `SingularComponentSelector`, i.e., itself"
get_groups(selector::SingularComponentSelector, sys; scope_limiter = nothing) = [selector]

"""
    get_component(selector, sys; scope_limiter = nothing)
Get the component of the collection that makes up the `SingularComponentSelector`; `nothing`
if there is none.
 - `scope_limiter`: optional filter function to apply after evaluating the `ComponentSelector`
"""
function get_component(
    selector::SingularComponentSelector,
    sys::SystemLike;
    scope_limiter = nothing,
)
    components = get_components(selector, sys; scope_limiter = scope_limiter)
    isempty(components) && return nothing
    return only(components)
end

"""
    get_component(scope_limiter, selector, sys)
Get the component of the collection that makes up the `SingularComponentSelector`; `nothing`
if there is none.
 - `scope_limiter`: optional filter function to apply after evaluating the `ComponentSelector`
"""
get_component(
    scope_limiter::Union{Nothing, Function},
    selector::SingularComponentSelector,
    sys::SystemLike,
) =
    get_component(selector, sys; scope_limiter = scope_limiter)

# CONCRETE SUBTYPE IMPLEMENTATIONS
# NameComponentSelector
"`ComponentSelector` that refers by name to at most a single component."
struct NameComponentSelector <: SingularComponentSelector
    component_type::Type{<:InfrastructureSystemsComponent}
    component_name::AbstractString
    name::Union{String, Nothing}
end

# Construction
"""
Make a `ComponentSelector` pointing to a component with the given type and name.
Optionally provide a name for the `ComponentSelector`.
"""
make_selector(
    component_type::Type{<:InfrastructureSystemsComponent},
    component_name::AbstractString;
    name::Union{String, Nothing} = nothing,
) = NameComponentSelector(component_type, component_name, name)
"""
Make a `ComponentSelector` from a component, pointing to components in any collection with
the given component's type and name. Optionally provide a name for the `ComponentSelector`.
"""
make_selector(
    component::InfrastructureSystemsComponent;
    name::Union{String, Nothing} = nothing,
) =
    make_selector(typeof(component), get_name(component)::AbstractString; name = name)

# Naming
default_name(selector::NameComponentSelector) =
    component_to_qualified_string(selector.component_type, selector.component_name)

# Contents
function get_components(
    selector::NameComponentSelector,
    sys::SystemLike;
    scope_limiter = nothing,
)
    com = get_component(selector.component_type, sys, selector.component_name)
    (!isnothing(scope_limiter) && !scope_limiter(com)) && (com = nothing)
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
default_name(selector::ListComponentSelector) =
    "[$(join(get_name.(selector.content), ", "))]"

# Contents
function get_groups(selector::ListComponentSelector, sys; scope_limiter = nothing)
    return selector.content
end

function get_components(
    selector::ListComponentSelector,
    sys::SystemLike;
    scope_limiter = nothing,
)
    sub_components =
        Iterators.map(
            x -> get_components(x, sys; scope_limiter = scope_limiter),
            selector.content,
        )
    return Iterators.flatten(sub_components)
end

# TypeComponentSelector
"`PluralComponentSelector` represented by a type of component."
struct TypeComponentSelector <: DynamicallyGroupedComponentSelector
    component_type::Type{<:InfrastructureSystemsComponent}
    name::Union{String, Nothing}
    groupby::Union{Symbol, Function}
end

# Construction
"""
Make a `ComponentSelector` from a type of component. Optionally provide a name and/or
grouping behavior for the `ComponentSelector`.
"""
make_selector(
    component_type::Type{<:InfrastructureSystemsComponent};
    name::Union{String, Nothing} = nothing,
    groupby::Union{Symbol, Function} = :all,
) =
    TypeComponentSelector(component_type, name, validate_groupby(groupby))

# Naming
default_name(selector::TypeComponentSelector) = subtype_to_string(selector.component_type)

# Contents
function get_components(
    selector::TypeComponentSelector,
    sys::SystemLike;
    scope_limiter = nothing,
)
    components = get_components(selector.component_type, sys)
    isnothing(scope_limiter) && (return components)
    return Iterators.filter(scope_limiter, components)
end

# FilterComponentSelector
"`PluralComponentSelector` represented by a filter function and a type of component."
struct FilterComponentSelector <: DynamicallyGroupedComponentSelector
    component_type::Type{<:InfrastructureSystemsComponent}
    filter_func::Function
    name::Union{String, Nothing}
    groupby::Union{Symbol, Function}
end

# Construction
# Could try to validate filter_func here, probably not worth it
# Signature 1: put the type first for consistency with many other `make_selector` methods
"""
Make a ComponentSelector from a filter function and a type of component. The filter function
must accept instances of `component_type` as a sole argument and return a `Bool`. Optionally
provide a name and/or grouping behavior for the `ComponentSelector`.
"""
make_selector(
    component_type::Type{<:InfrastructureSystemsComponent},
    filter_func::Function; name::Union{String, Nothing} = nothing,
    groupby::Union{Symbol, Function} = :all,
) = FilterComponentSelector(component_type, filter_func, name, validate_groupby(groupby))

# Signature 2: put the filter function first for consistency with non-`ComponentSelector` `get_components`
"""
Make a ComponentSelector from a filter function and a type of component. The filter function
must accept instances of `component_type` as a sole argument and return a `Bool`. Optionally
provide a name and/or grouping behavior for the `ComponentSelector`.
"""
make_selector(
    filter_func::Function,
    component_type::Type{<:InfrastructureSystemsComponent};
    name::Union{String, Nothing} = nothing,
    groupby::Union{Symbol, Function} = :all,
) = FilterComponentSelector(component_type, filter_func, name, validate_groupby(groupby))

# Contents
function get_components(
    selector::FilterComponentSelector,
    sys::SystemLike;
    scope_limiter = nothing,
)
    # Short-circuit-evaluate the `scope_limiter` first so `filter_func` may refer to
    # component attributes that do not exist in components outside the scope
    combo_filter = if isnothing(scope_limiter)
        selector.filter_func
    else
        x -> scope_limiter(x) && selector.filter_func(x)
    end
    components = get_components(combo_filter, selector.component_type, sys)
    return components
end

# Naming
default_name(selector::FilterComponentSelector) =
    string(selector.filter_func) * COMPONENT_NAME_DELIMITER *
    subtype_to_string(selector.component_type)
