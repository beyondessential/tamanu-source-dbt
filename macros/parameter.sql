{%- macro parameter(parameter_name, default_value=null, data_type='text') -%}
    {% if flags.WHICH == 'compile' %} :{{parameter_name}}{% else %}'{{var(parameter_name, default_value)}}'::{{data_type}}{% endif %}
{%- endmacro %}
