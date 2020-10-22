# Components and System

## Component structs

InfrastructureSystems provides a common way of managing component structs in a
system.

## Type hierachy

Make every component a subtype of InfrastructureSystemsComponent.

## Interface requirements

Implement a `get_name(c::MyComponent)::String` method for every struct.

## InfrastructureSystemsInternal

Add this struct to every component struct.

- It automatically creates a UUID for the component. This guarantees a unique
  way to identify the component.
- It optionally provides an extension dictionary for user data. A user
  extending your package may want to use your struct but need one more field.
  Rather than create a new type they can add data to this `ext` object.

## Instructions to implement a component

1. Add the field to your struct. The constructor does not take any parameters.

```julia
struct MyComponent
    internal::InfrastructureSystemsInternal
end

# Optional
get_ext(c::MyComponent) = InfrastructureSystems.get_ext(c.ext)
clear_ext!(c::MyComponent) = InfrastructureSystems.clear_ext(c.ext)
```

*Notes*:

- `InfrastructureSystems.get_uuid(obj::InfrastructureSystemsComponent)` returns the
  component UUID.
- The extension dictionary is not created until the first time `get_ext` is
  called.

## Component container

InfrastructureSystems provides the `SystemData` struct to store a collection of
components.

It is recommended but not required that you include this struct within your own
  system struct for these reasons:

- Provides search and iteration with `get_component` and `get_components` for
  abstract and concrete types.
- Enforces name uniqueness within a concrete type.
- Allows for component field validation.
- Enables component JSON serialization and deserialization.

## Instructions to use the System container

1. Add an instance of `SystemData` to your system struct.
2. Optionally pass a component validation descriptor file to the constructor.
3. Optionally pass `time_series_in_memory = true` to the constructor if you
   know that all time series data will fit in memory and want a performance
   boost.
4. Redirect these function calls to your instance of SystemData.

- `add_component!`
- `remove_component!`
- `get_component`
- `get_components`
- `get_components_by_name`
- `add_time_series!`
