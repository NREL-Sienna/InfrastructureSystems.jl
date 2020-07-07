
import Mustache

template = """
#=
This file is auto-generated. Do not edit.
=#
\"\"\"
    mutable struct {{struct_name}}{{#parametric}}{T <: {{parametric}}}{{/parametric}} <: {{supertype}}
        {{#parameters}}
        {{name}}::{{{data_type}}}
        {{/parameters}}
    end

{{#docstring}}{{{docstring}}}{{/docstring}}

# Arguments
{{#parameters}}
- `{{name}}::{{{data_type}}}`{{#comment}}: {{{comment}}}{{/comment}}{{#valid_range}}, validation range: {{valid_range}}{{/valid_range}}{{#validation_action}}, action if invalid: {{validation_action}}{{/validation_action}}
{{/parameters}}
\"\"\"
mutable struct {{struct_name}}{{#parametric}}{T <: {{parametric}}}{{/parametric}} <: {{supertype}}
    {{#parameters}}
    {{#comment}}"{{{comment}}}"\n    {{/comment}}{{name}}::{{{data_type}}}
    {{/parameters}}
    {{#inner_constructor_check}}

    function {{struct_name}}({{#parameters}}{{name}}, {{/parameters}})
        ({{#parameters}}{{name}}, {{/parameters}}) = {{inner_constructor_check}}(
            {{#parameters}}
            {{name}},
            {{/parameters}}
        )
        new({{#parameters}}{{name}}, {{/parameters}})
    end
    {{/inner_constructor_check}}
end

{{#needs_positional_constructor}}
function {{constructor_func}}({{#parameters}}{{^internal_default}}{{name}}{{#default}}={{default}}{{/default}}, {{/internal_default}}{{/parameters}}){{{closing_constructor_text}}}
    {{constructor_func}}({{#parameters}}{{^internal_default}}{{name}}, {{/internal_default}}{{/parameters}}{{#parameters}}{{#internal_default}}{{{internal_default}}}, {{/internal_default}}{{/parameters}})
end
{{/needs_positional_constructor}}

function {{constructor_func}}(; {{#parameters}}{{^internal_default}}{{name}}{{#default}}={{default}}{{/default}}, {{/internal_default}}{{/parameters}}){{{closing_constructor_text}}}
    {{constructor_func}}({{#parameters}}{{^internal_default}}{{name}}, {{/internal_default}}{{/parameters}})
end

{{#has_null_values}}
# Constructor for demo purposes; non-functional.
function {{constructor_func}}(::Nothing){{{closing_constructor_text}}}
    {{constructor_func}}(;
        {{#parameters}}
        {{^internal_default}}
        {{name}}={{#quotes}}"{{null_value}}"{{/quotes}}{{^quotes}}{{null_value}}{{/quotes}},
        {{/internal_default}}
        {{/parameters}}
    )
end

{{/has_null_values}}
{{#accessors}}
{{#create_docstring}}\"\"\"Get {{struct_name}} {{name}}.\"\"\"{{/create_docstring}}
{{accessor}}(value::{{struct_name}}) = {{#needs_conversion}}get_value(value, :{{name}}){{/needs_conversion}}{{^needs_conversion}}value.{{name}}{{/needs_conversion}}
{{/accessors}}

{{#setters}}
{{#create_docstring}}\"\"\"Set {{struct_name}} {{name}}.\"\"\"{{/create_docstring}}
{{setter}}(value::{{struct_name}}, val::{{data_type}}) = value.{{name}} = val
{{/setters}}
"""

function read_json_data(filename::String)
    return open(filename) do io
        data = JSON.parse(io)
        if data isa Array
            return data
        elseif data isa Dict && haskey(data, "auto_generated_structs")
            return data["auto_generated_structs"]
        else
            throw(DataFormatError("{filename} has invalid format"))
        end
    end
end

function generate_structs(directory, data::Vector; print_results = true)
    struct_names = Vector{String}()
    unique_accessor_functions = Set{String}()
    unique_setter_functions = Set{String}()

    for item in data
        has_internal = false
        accessors = Vector{Dict}()
        setters = Vector{Dict}()
        item["has_null_values"] = true

        item["constructor_func"] = item["struct_name"]
        item["closing_constructor_text"] = ""
        if haskey(item, "parametric")
            item["constructor_func"] *= "{T}"
            item["closing_constructor_text"] = " where T <: $(item["parametric"])"
        end

        parameters = Vector{Dict}()
        for field in item["fields"]
            param = field
            if haskey(param, "valid_range")
                if typeof(param["valid_range"]) == Dict{String, Any}
                    param["valid_range"] =
                        param["valid_range"]["min"], param["valid_range"]["max"]
                elseif typeof(param["valid_range"]) == String
                    param["valid_range"] = param["valid_range"]
                end
            end
            push!(parameters, param)

            # Allow accessor functions to be re-implemented from another module.
            # If this key is defined then the accessor function will not be exported.
            # Example:  get_name is defined in InfrastructureSystems and re-implemented in
            # PowerSystems.
            if haskey(param, "accessor_module")
                accessor_module = param["accessor_module"] * "."
                create_docstring = false
            else
                accessor_module = ""
                create_docstring = true
            end
            accessor_name = accessor_module * "get_" * param["name"]
            setter_name = accessor_module * "set_" * param["name"] * "!"
            push!(
                accessors,
                Dict(
                    "name" => param["name"],
                    "accessor" => accessor_name,
                    "create_docstring" => create_docstring,
                    "needs_conversion" => get(param, "needs_conversion", false)
                ),
            )
            include_setter = !get(param, "exclude_setter", false)
            if include_setter
                push!(
                    setters,
                    Dict(
                        "name" => param["name"],
                        "setter" => setter_name,
                        "data_type" => param["data_type"],
                        "create_docstring" => create_docstring,
                    ),
                )
            end
            if accessor_name != "internal" && accessor_module == ""
                push!(unique_accessor_functions, accessor_name)
                push!(unique_setter_functions, setter_name)
            end

            if haskey(param, "internal_default")
                has_internal = true
                continue
            end

            # This controls whether a kwargs constructor will be generated.
            if !haskey(param, "null_value")
                item["has_null_values"] = false
            else
                if param["data_type"] == "String"
                    param["quotes"] = true
                end
            end
            param["struct_name"] = item["struct_name"]
        end

        item["parameters"] = parameters
        item["accessors"] = accessors
        item["setters"] = setters
        item["needs_positional_constructor"] = has_internal

        filename = joinpath(directory, item["struct_name"] * ".jl")
        open(filename, "w") do io
            write(io, Mustache.render(template, item))
            push!(struct_names, item["struct_name"])
        end

        if print_results
            println("Wrote $filename")
        end
    end

    accessors = sort!(collect(unique_accessor_functions))
    setters = sort!(collect(unique_setter_functions))
    filename = joinpath(directory, "includes.jl")
    open(filename, "w") do io
        for name in struct_names
            write(io, "include(\"$name.jl\")\n")
        end
        write(io, "\n")

        for accessor in accessors
            write(io, "export $accessor\n")
        end
        for setter in setters
            write(io, "export $setter\n")
        end
        if print_results
            println("Wrote $filename")
        end
    end
end

function namedtuple_to_dict(tuple)
    parameters = Dict()
    for property in propertynames(tuple)
        parameters[string(property)] = getproperty(tuple, property)
    end

    return parameters
end

function generate_structs(
    input_file::AbstractString,
    output_directory::AbstractString;
    print_results = true,
)
    # Include each generated file.
    if !isdir(output_directory)
        mkdir(output_directory)
    end

    data = read_json_data(input_file)
    generate_structs(output_directory, data, print_results = print_results)
end

"""
Return true if the structs defined in existing_dir match structs freshly-generated
from descriptor_file.
"""
function test_generated_structs(descriptor_file, existing_dir)
    output_dir = "tmp-test-generated-structs"
    if isdir(output_dir)
        rm(output_dir; recursive = true)
    end
    mkdir(output_dir)

    generate_structs(descriptor_file, output_dir; print_results = false)

    matched = true
    try
        run(`diff --strip-trailing-cr $output_dir $existing_dir`)
    catch err
        @error "Generated structs do not match the descriptor file." err
        matched = false
    finally
        rm(output_dir; recursive = true)
    end

    return matched
end
