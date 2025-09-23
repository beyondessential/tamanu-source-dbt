{% macro resolve_input_model(model_base_name) %}
    {% set source_type = var('base_model_source_type', 'source') %}
    {% if source_type == 'source' %}
        {{ return(source("tamanu", model_base_name)) }}
    {% elif source_type == 'reconstructed' %}
        {%- set rec__model_name = 'rec__' ~ model_base_name -%}
        {{ return(ref(rec__model_name)) }}
    {% else %}
        {{ exceptions.raise_compiler_error("Invalid `base_model_source_type` value: " ~ source_type ~ ". Expected 'source' or 'reconstructed'.") }}
    {% endif %}

{% endmacro %}
