{%- macro parameter(parameter_name, default_value, data_type='text') -%}
    {%- if flags.WHICH == 'compile' %}
        :{{ parameter_name }}
    {%- else -%}
        {%- set param_value = var(parameter_name, default_value) -%}
        {%- if data_type is none -%}
            nullif('{{ param_value }}', '')
        {%- else -%}
            nullif('{{ param_value }}', '')::{{ data_type }}
        {%- endif -%}
    {%- endif -%}
{%- endmacro %}