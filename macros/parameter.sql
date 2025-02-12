{%- macro parameter(parameter_name, default_value=null, data_type='text') -%}
    {%- if flags.WHICH == 'compile' %}
        :{{ parameter_name }}
    {%- else -%}
        {%- set param_value = var(parameter_name, default_value) -%}
        {%- if data_type is none -%}
            '{{ param_value }}'
        {%- else -%}
            '{{ param_value }}'::{{ data_type }}
        {%- endif -%}
    {%- endif -%}
{%- endmacro %}
