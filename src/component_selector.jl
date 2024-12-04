# ABSTRACT TYPE DEFINITIONS
#=
`ComponentSelector` extension notes:
Concrete subtypes MUST implement:
 - `get_components`: returns an iterable of components
 - `get_name`: returns a name for the selector -- or use the default by having a `name::String` field
 - `get_groups`: returns an iterable of `ComponentSelector`s
 - `rebuild_selector`: returns a new `ComponentSelector` (need not be the same concrete
   type) with the changes given in the keyword arguments. `name` MUST be a valid keyword
   argument; it is up to the extender what other attributes of the selector may be rebuilt.
   There is a default that may suffice.

Concrete subtypes SHOULD implement:
 - The factory method `make_selector` (make sure your signature does not conflict with an
   existing one)

New system-like types MUST ensure that `get_available_components` and `get_available_groups`
work for them, likely either by using the default if all components are always available or
by implementing a method that uses `get_components`'s `scope_limiter` kwarg to specify the
proper filtering.
=#

"The base type for all `ComponentSelector`s."
abstract type ComponentSelector end

#=
`SingularComponentSelector` extension notes:
The interface is the same as for `ComponentSelector` except:
 - `get_components` MUST return zero or one components
 - `get_component` MUST be implemented: return `nothing` where `get_components` would return
   zero components, else return an iterator of the one component
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
const DEFAULT_GROUPBY = :each

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

# Override this if you define a ComponentSelector subtype with no name field
"""
Get the name of the `ComponentSelector`. This is either the default name or a custom name
passed in at creation time.
"""
get_name(selector::ComponentSelector) = selector.name

"""
    get_components(selector, sys)
Get the components of the collection that make up the `ComponentSelector`.
"""
function get_components end

"""
    get_available_components(selector, sys)
Get the available components of the collection that make up the `ComponentSelector`.
"""
get_available_components(selector::ComponentSelector, sys) =
    get_components(selector, sys)

"""
    get_groups(selector, sys)
Get the groups that make up the `ComponentSelector`.
"""
function get_groups end

"""
    get_available_groups(selector, sys)
Get the available groups of the collection that make up the `ComponentSelector`.
"""
get_available_groups(selector::ComponentSelector, sys) =
    get_groups(selector, sys)

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
    kwargs...,
)
    (selector.groupby == :all) && return [selector]
    (selector.groupby == :each) &&
        return Iterators.map(make_selector,
            get_components(selector, sys; kwargs...))
    @assert selector.groupby isa Function
    components = collect(get_components(selector, sys; kwargs...))

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
get_groups(selector::SingularComponentSelector, sys; kwargs...) = [selector]

"""
    get_component(selector, sys)
Get the component of the collection that makes up the `SingularComponentSelector`; `nothing`
if there is none.
"""
function get_component end

# Fallback `rebuild_selector` that only handles `name`
"""
Returns a `ComponentSelector` functionally identical to the input `selector` except with the
changes to its fields specified in the keyword arguments.

# Examples
Suppose you have a selector with `name = "my_name`. If you instead wanted `name = "your_name`:
```julia
sel = make_selector(ThermalStandard, "322_CT_6"; name = "my_name")
sel_yours = rebuild_selector(sel; name = "your_name")
```
"""
function rebuild_selector(selector::T; name = nothing) where {T <: ComponentSelector}
    selector_data =
        Dict(key => getfield(selector, key) for key in fieldnames(typeof(selector)))
    isnothing(name) || (selector_data[:name] = name)
    return T(; selector_data...)
end

"""
Returns a `ComponentSelector` functionally identical to the input `selector` except with the
changes to its fields specified in the keyword arguments.

# Examples
Suppose you have a selector with `groupby = :all`. If you instead wanted `groupby = :each`:
```julia
sel = make_selector(ThermalStandard; groupby = :all)
sel_each = rebuild_selector(sel; groupby = :each)
```
"""
function rebuild_selector(selector::T;
    name = nothing, groupby = nothing) where {T <: DynamicallyGroupedComponentSelector}
    selector_data =
        Dict(key => getfield(selector, key) for key in fieldnames(typeof(selector)))
    isnothing(name) || (selector_data[:name] = name)
    isnothing(groupby) || (selector_data[:groupby] = groupby)
    return T(; selector_data...)
end

# CONCRETE SUBTYPE IMPLEMENTATIONS
# NameComponentSelector
"`ComponentSelector` that refers by name to at most a single component."
@kwdef struct NameComponentSelector <: SingularComponentSelector
    component_type::Type{<:InfrastructureSystemsComponent}
    component_name::AbstractString
    name::String
end

# Construction
NameComponentSelector(
    component_type::Type{<:InfrastructureSystemsComponent},
    component_name::AbstractString,
    name::Nothing = nothing,
) =
    NameComponentSelector(
        component_type,
        component_name,
        component_to_qualified_string(component_type, component_name),
    )

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

# Contents
function get_component(selector::NameComponentSelector, sys; kwargs...)
    com = get_component(selector.component_type, sys, selector.component_name)
    isnothing(com) && return nothing
    scope_limiter = get(kwargs, :scope_limiter, nothing)
    (!isnothing(scope_limiter) && !scope_limiter(com)) && return nothing
    return com
end

function get_components(selector::NameComponentSelector, sys; kwargs...)
    com = get_component(selector, sys; kwargs...)
    isnothing(com) && return _make_empty_iterator(selector.component_type)
    # Wrap the one component up in a bunch of other data structures to get the Sienna standard type for this
    com_dict = Dict(selector.component_name => com)
    return _make_iterator_from_concrete_dict(selector.component_type, com_dict)
end

# ListComponentSelector
"`PluralComponentSelector` represented by a list of other `ComponentSelector`s."
@kwdef struct ListComponentSelector <: PluralComponentSelector
    # Using tuples internally for immutability => `==` is automatically well-behaved
    content::Tuple{Vararg{ComponentSelector}}
    name::String
end

# Construction
ListComponentSelector(content::Tuple{Vararg{ComponentSelector}}, name::Nothing = nothing) =
    ListComponentSelector(content, "[$(join(get_name.(content), ", "))]")

"""
Make a `ComponentSelector` pointing to a list of sub-selectors, which form the groups.
Optionally provide a name for the `ComponentSelector`.
"""
make_selector(content::ComponentSelector...; name::Union{String, Nothing} = nothing) =
    ListComponentSelector(content, name)

# Contents
function get_groups(selector::ListComponentSelector, sys; kwargs...)
    return selector.content
end

function get_components(selector::ListComponentSelector, sys; kwargs...)
    sub_components =
        map(
            x -> get_components(x, sys; kwargs...),
            selector.content,
        )
    my_supertype = typejoin(eltype.(sub_components)...)
    return FlattenIteratorWrapper(my_supertype, sub_components)
end

# Rebuilding
"""
Returns a `ComponentSelector` functionally identical to the input `selector` except with the
changes to its fields specified in the keyword arguments. For `ListComponentSelector`, if a
`groupby` option is specified, the return type will be a `RegroupedComponentSelector`
instead of a `ListComponentSelector`.

# Examples
Suppose you have a selector with manual groups and you want to group by `:each`:
```julia
sel = make_selector(make_selector(ThermalStandard), make_selector(RenewableDispatch))
sel_each = rebuild_selector(sel; groupby = :each)  # will be a RegroupedComponentSelector
```
"""
function rebuild_selector(selector::ListComponentSelector;
    name = nothing, groupby = nothing)
    # Handle the easy stuff first
    selector_data =
        Dict(key => getfield(selector, key) for key in fieldnames(typeof(selector)))
    isnothing(name) || (selector_data[:name] = name)
    rebuilt = ListComponentSelector(; selector_data...)

    # Wrap in a RegroupedComponentSelector if we need to
    isnothing(groupby) && return rebuilt
    return RegroupedComponentSelector(rebuilt, groupby)
end

# TypeComponentSelector
"`PluralComponentSelector` represented by a type of component."
@kwdef struct TypeComponentSelector <: DynamicallyGroupedComponentSelector
    component_type::Type{<:InfrastructureSystemsComponent}
    groupby::Union{Symbol, Function}
    name::String

    TypeComponentSelector(
        component_type::Type{<:InfrastructureSystemsComponent},
        groupby::Union{Symbol, Function},
        name::String,
    ) = new(component_type, validate_groupby(groupby), name)
end

# Construction
TypeComponentSelector(
    component_type::Type{<:InfrastructureSystemsComponent},
    groupby::Union{Symbol, Function},
    name::Nothing = nothing,
) = TypeComponentSelector(component_type, groupby, subtype_to_string(component_type))

"""
Make a `ComponentSelector` from a type of component. Optionally provide a name and/or
grouping behavior for the `ComponentSelector`.
"""
make_selector(
    component_type::Type{<:InfrastructureSystemsComponent};
    groupby::Union{Symbol, Function} = DEFAULT_GROUPBY,
    name::Union{String, Nothing} = nothing,
) = TypeComponentSelector(component_type, groupby, name)

# Contents
function get_components(selector::TypeComponentSelector, sys; kwargs...)
    scope_limiter = get(kwargs, :scope_limiter, nothing)
    isnothing(scope_limiter) && return get_components(selector.component_type, sys)
    return get_components(scope_limiter, selector.component_type, sys)
end

# FilterComponentSelector
"`PluralComponentSelector` represented by a filter function and a type of component."
@kwdef struct FilterComponentSelector <: DynamicallyGroupedComponentSelector
    component_type::Type{<:InfrastructureSystemsComponent}
    filter_func::Function
    groupby::Union{Symbol, Function}
    name::String

    FilterComponentSelector(
        component_type::Type{<:InfrastructureSystemsComponent},
        filter_func::Function,
        groupby::Union{Symbol, Function},
        name::String,
    ) = new(component_type, filter_func, validate_groupby(groupby), name)
end

# Construction
FilterComponentSelector(
    component_type::Type{<:InfrastructureSystemsComponent},
    filter_func::Function,
    groupby::Union{Symbol, Function},
    name::Nothing = nothing,
) =
    FilterComponentSelector(
        component_type,
        filter_func,
        groupby,
        string(filter_func) * COMPONENT_NAME_DELIMITER * subtype_to_string(component_type),
    )

"""
Make a ComponentSelector from a filter function and a type of component. The filter function
must accept instances of `component_type` as a sole argument and return a `Bool`. Optionally
provide a name and/or grouping behavior for the `ComponentSelector`.
"""
make_selector(
    filter_func::Function,
    component_type::Type{<:InfrastructureSystemsComponent};
    name::Union{String, Nothing} = nothing,
    groupby::Union{Symbol, Function} = DEFAULT_GROUPBY,
) = FilterComponentSelector(component_type, filter_func, groupby, name)

# Contents
function get_components(selector::FilterComponentSelector, sys; kwargs...)
    # Short-circuit-evaluate the `scope_limiter` first so `filter_func` may refer to
    # component attributes that do not exist in components outside the scope
    scope_limiter = get(kwargs, :scope_limiter, nothing)
    combo_filter = if isnothing(scope_limiter)
        selector.filter_func
    else
        x -> scope_limiter(x) && selector.filter_func(x)
    end
    components = get_components(combo_filter, selector.component_type, sys)
    return components
end

# RegroupedComponentSelector
"`PluralComponentSelector` that wraps another `ComponentSelector` and applies dynamic grouping."
@kwdef struct RegroupedComponentSelector <: DynamicallyGroupedComponentSelector
    wrapped_selector::ComponentSelector
    groupby::Union{Symbol, Function}

    RegroupedComponentSelector(
        wrapped_selector::ComponentSelector,
        groupby::Union{Symbol, Function},
    ) = new(wrapped_selector, validate_groupby(groupby))
end

# Naming
get_name(selector::RegroupedComponentSelector) = get_name(selector.wrapped_selector)

# Contents
get_components(selector::RegroupedComponentSelector, sys; kwargs...) =
    get_components(selector.wrapped_selector, sys; kwargs...)
