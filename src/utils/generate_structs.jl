
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
- `{{name}}::{{{data_type}}}`{{#comment}}: {{{comment}}}{{/comment}}
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

{{#needs_positional_constructor}}function {{struct_name}}({{#parameters}}{{^internal}}{{name}}{{#default}}={{default}}{{/default}}, {{/internal}}{{/parameters}})
    {{struct_name}}({{#parameters}}{{^internal}}{{name}}, {{/internal}}{{/parameters}}InfrastructureSystemsInternal())
end{{/needs_positional_constructor}}

function {{struct_name}}(; {{#parameters}}{{^internal}}{{name}}{{#default}}={{default}}{{/default}}, {{/internal}}{{/parameters}})
    {{struct_name}}({{#parameters}}{{^internal}}{{name}}, {{/internal}}{{/parameters}})
end

{{#parametric}}
function {{struct_name}}{T}({{#parameters}}{{^internal}}{{name}}{{#default}}={{default}}{{/default}}, {{/internal}}{{/parameters}}) where T <: InfrastructureSystemsType
    {{struct_name}}({{#parameters}}{{^internal}}{{name}}, {{/internal}}{{/parameters}}InfrastructureSystemsInternal())
end
{{/parametric}}

{{#defines_ext}}
function {{struct_name}}({{#parameters}}{{^internal}}{{^ext}}{{^_forecasts}}{{name}}, {{/_forecasts}}{{/ext}}{{/internal}}{{/parameters}}; ext={{#parameters}}{{#ext}}{{default}}{{/ext}}{{/parameters}})
    {{#parameters}}{{#_forecasts}}_forecasts={{default}}{{/_forecasts}}{{/parameters}}
    {{struct_name}}({{#parameters}}{{^internal}}{{name}}, {{/internal}}{{/parameters}}InfrastructureSystemsInternal())
end
{{/defines_ext}}

{{#has_null_values}}
# Constructor for demo purposes; non-functional.

function {{struct_name}}(::Nothing)
    {{struct_name}}(;
        {{#parameters}}
        {{^internal}}
        {{name}}={{#quotes}}"{{null_value}}"{{/quotes}}{{^quotes}}{{null_value}}{{/quotes}},
        {{/internal}}
        {{/parameters}}
    )
end
{{/has_null_values}}

{{#accessors}}
\"\"\"Get {{struct_name}} {{name}}.\"\"\"
{{accessor}}(value::{{struct_name}}) = value.{{name}}
{{/accessors}}
"""

function read_json_data(filename::String)
    return open(filename) do io
        data = JSON2.read(io, Vector{Dict})
    end
end

function generate_structs(directory, data::Vector; print_results=true)
    struct_names = Vector{String}()
    unique_accessor_functions = Set{String}()

    for item in data
        has_internal = false
        defines_ext = false
        accessors = Vector{Dict}()
        item["has_null_values"] = true
        parameters = Vector{Dict}()
        for field in item["fields"]
            param = namedtuple_to_dict(field)
            push!(parameters, param)
            accessor_name = "get_" * param["name"]
            push!(accessors, Dict("name" => param["name"], "accessor" => accessor_name))
            if accessor_name != "internal"
                push!(unique_accessor_functions, accessor_name)
            end

            if param["name"] == "internal"
                param["internal"] = true
                has_internal = true
                continue
            end

            if param["name"] == "ext"
                param["ext"] = true
                defines_ext = true
                continue
            end

            if param["name"] == "_forecasts"
                param["_forecasts"] = true
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
        item["needs_positional_constructor"] = has_internal
        item["defines_ext"] = defines_ext

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

    filename = joinpath(directory, "includes.jl")
    open(filename, "w") do io
        for name in struct_names
            write(io, "include(\"$name.jl\")\n")
        end
        write(io, "\n")

        for accessor in accessors
            write(io, "export $accessor\n")
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

function generate_structs(input_file::AbstractString, output_directory::AbstractString;
                          print_results=true)
    # Include each generated file.
    if !isdir(output_directory)
        mkdir(output_directory)
    end

    data = read_json_data(input_file)
    generate_structs(output_directory, data, print_results=print_results)
end
