# User Guide

## Component structs
InfrastructureSystems provides a common way of managing component structs in a
system.

### Type hierachy
Make every component a subtype of InfrastructureSystemsType.

#### Interface requirements
Implement a `get_name(c::MyComponent)::String` method for every struct.

### InfrastructureSystemsInternal
Add this struct to every component struct.

- It automatically creates a UUID for the component. This guarantees a unique
  way to identify the component.
- It optionally provides an extension dictionary for user data. A user
  extending your package may want to use your struct but need one more field.
  Rather than create a new type they can add data to this `ext` object.

#### Instructions

1. Add the field to your struct. The constructor does not take any parameters.
```julia
struct MyComponent
    internal::InfrastructureSystemsInternal
end

# Optional
get_ext(c::MyComponent) = InfrastructureSystems.get_ext(c.ext)
clear_ext(c::MyComponent) = InfrastructureSystems.clear_ext(c.ext)
```

*Notes*:
- `InfrastructureSystems.get_uuid(obj::InfrastructureSystemsType)` returns the
  component UUID.
- The extension dictionary is not created until the first time `get_ext` is
  called.

### Auto-Generation of component structs
InfrastructureSystems provides a mechanism to auto-generate Julia files
containing structs and field accessor functions from JSON descriptors. Here are
reasons to consider using this approach:

- Auto-generation allows for easy refactoring of code. Adding fields
  to many structs can be tedious because you might have to edit many
  constructors. This process eliminates boiler-plate edits.
- The JSON descriptor format includes a mechanisim to define range validation
  on component fields. Validation can be enabled when adding components to a
  system.
- Provides consistent formatting of structs, fields, and constructors.
- Provides consistent documentation of structs and fields.

#### Instructions

1. Create the JSON descriptor file. Follow the
   [PowerSystems.jl](https://github.com/NREL-SIIP/PowerSystems.jl/blob/master/src/descriptors/power_system_structs.json)
   example.
2. Run the generation script, passing your descriptor file and an output
   directory.

```julia
InfrastructureSystems.generate_structs("./src/descriptors/power_system_structs.json", "./src/models/generated")
```

*Notes*:
- The code generation template provides several options which are not yet
  formally documented. Browse the PowerSystems example or the generation script.
- You will need to decide how to manage the generated files. The PowerSystems
  package keeps the generated code in the git repository. This is not required.
  You could choose to generate them at startup.
- You may need to create custom constructors and this approach will not allow
  you have put them in the same file as the struct definition.

### Component time series data
InfrastructureSystems provides a mechanism to store time series data for
components. Here are reasons to consider using it:

- Time series data, by default, is stored independently of components in HDF5
  files. Components store references to that data.
  - System memory is not depleted by loading all time series data at once. Only
    data that you need is loaded.
  - Multiple components can share the same time series data by sharing
    references instead of making expensive copies.
- Supports serialization and deserialization.
- Supports parsing raw data files of several formats as well as data stored in
  `TimeSeries.TimeArray` and `DataFrames.DataFrame` objects.

> :warning: **You must reimplement deepcopy if you use HDF5**

If you store an instance of `SystemData` within your system and then a user
calls `deepcopy` on a system, the .h5 file will not be copied. The new and
old instances will have references to the same file. You will need to
reimplement `deepcopy` to handle this. One solution is to serialize and then
deserialize the system.

*Notes*:
- Time series data can optionally be stored fully in memory. Refer to the
[SystemData](https://nrel-siip.github.io/InfrastructureSystems.jl/latest/api/InfrastructureSystems/#InfrastructureSystems.SystemData-Tuple{AbstractString})
documentation.
- InfrastructureSystems creates HDF5 files on the tmp filesystem by default.
  This can be changed if the time series data is larger than the amount of
  tmp space available. Refer to the `SystemData` link above.

#### Instructions

1. Add an instance of `InfrastructureSystems.Forecasts` to the component struct.
2. Implement the method `InfrastructureSystems.get_forecasts` for the
   component. It must return the Forecasts object.

### Component container
InfrastructureSystems provides the `SystemData` struct to store a collection of
components.

It is recommended but not required that you include this struct within your own
  system struct for these reasons:

- Provides search and iteration with `get_component` and `get_components` for
  abstract and concrete types.
- Enforces name uniqueness within a concrete type.
- Allows for component field validation.
- Enables component JSON serialization and deserialization.

#### Instructions

1. Add an instance of `SystemData` to your system struct.
2. Optionally pass a component validation descriptor file to the constructor.
3. Optionally pass `time_series_in_memory = true` to the constructor if you
   know that all time series data will fit in memory and want a performance
   boost.
4. Redirect these function calls to your instance of SystemData.
   * `add_component!`
   * `remove_component!`
   * `get_component`
   * `get_components`
   * `get_components_by_name`
   * `add_forecasts!`
   * `add_forecast!`
   * `remove_forecast!`


## Logging
InfrastructureSystems provides a `MultiLogger` object that allows customized
logging to console and file. Refer to the [logging
documentation](./logging.md).

If you want to create a package-specific log file during a simulation, consider
the workflow used by PowerSimulations.jl. It creates a custom logger in its
`build!(Simulation)` function and then uses Julia's `Logging.with_logger`
function to temporarily take over the global logger during `build()` and
`execute()`.

## Recorder events
InfrastructureSystems provides a mechanism to store structured data in events
that get recorded in one or more files. They can be filtered and displayed in
tabular form.

The primary use is to store information that can help debug problems.  For
example, you may want to store all state transitions in a simulation or every
update of a variable.  If a problem occurs you can then display filtered tables
of that data to figure out what went wrong.

### Instructions
1. Create events that are subtypes of
   `InfrastructureSystems.AbstractRecorderEvent`. Include an instance of
   `RecorderEventCommon` in each struct.
2. Call `InfrastructureSystems.register_recorder(<recorder-name>)` for
   each recorder object you want to create.
   - Depending on how often your code create events you may want to make this
     conditional. You may only need it for debug runs.
   - PowerSimulations creates one recorder for simulation step and stage
     start/stop events that is always enabled. It creates another that is
     optional but used for frequently-generated events.
3. Call `@InfrastructureSystems.record <recorder-name> <event>` wherever you
   want to generate events in your code. The event will only get constructed if
   the recorder is registered.
4. Call `InfrastructureSystems.unregister_recorder(<recorder-name>)` for each
   registered recorder. You should guarantee this this gets called, even if an
   exception is thrown.  Otherwise, the file may not get flushed and closed.
5. After your code runs call `InfrastructureSystems.show_recorder_events` to
   view events.  Refer to the docstrings for more information.
6. Refer to
   [PowerSimulations.show_simulation_events](https://nrel-siip.github.io/PowerSimulations.jl/latest/api/PowerSimulations/#PowerSimulations.show_simulation_events-Union{Tuple{T},%20Tuple{Type{T},AbstractString},%20Tuple{Type{T},AbstractString,Union{Nothing,%20Function}}}%20where%20T%3C:InfrastructureSystems.AbstractRecorderEvent)
   for an example on how to customize this behavior for your package.
