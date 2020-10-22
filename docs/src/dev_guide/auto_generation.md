# Auto-Generation of Component Structs

`InfrastructureSystems.jl` provides a mechanism to auto-generate Julia files
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

## Instructions

1. Create the JSON descriptor file. Follow the
   [PowerSystems.jl](https://github.com/NREL-SIIP/PowerSystems.jl/blob/master/src/descriptors/power_system_structs.json)
   example.
2. Run the generation script, passing your descriptor file and an output
   directory.

```Julia
InfrastructureSystems.generate_structs("./src/descriptors/power_system_structs.json", "./src/models/generated")
```

*Notes*:

- The code generation template provides several options which are not yet
  formally documented. Browse the PowerSystems example or the generation script.
- You will need to decide how to manage the generated files. The SIIP packages keep the
  generated code in the git repository. This is not required.
  You could choose to generate them at startup.
- You may need to create custom constructors and this approach will not allow
  you have put them in the same file as the struct definition.
