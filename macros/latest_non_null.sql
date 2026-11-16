{% macro latest_non_null(expression, order_by) -%}
    (array_agg({{ expression }} order by {{ order_by }}) filter (where {{ expression }} is not null))[1]
{%- endmacro %}
