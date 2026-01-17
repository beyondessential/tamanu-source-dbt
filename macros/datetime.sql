{% macro get_current_date() %}
    {%- if var('test_current_date', None) -%}
        '{{ var('test_current_date') }}'::date
    {%- else -%}
        current_date
    {%- endif -%}
{% endmacro %}

{% macro get_current_timestamp() %}
    {%- if var('test_current_timestamp', None) -%}
        '{{ var('test_current_timestamp') }}'::timestamp
    {%- else -%}
        now()
    {%- endif -%}
{% endmacro %}
