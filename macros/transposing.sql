{% macro generate_select_attribute_values(group_by_columns, attribute_name, attribute_order, value_aggregate, where_conditions) %}
  select {{ group_by_columns }},
    '{{ attribute_name }}' as attribute,
    {{ attribute_order }} as attribute_order,
    {{ value_aggregate }} as value
	from filtered_ds
	where {{ where_conditions }}
	group by {{ group_by_columns }}
{% endmacro %}

{% macro generate_sum_case(transpose_column, value_column, transpose_column_values) %}
  {% if not transpose_column_values %}
    {% set transpose_column_values = range(1, 54) %}
  {% endif %}
  {% for value in transpose_column_values %}
  sum(case when {{ transpose_column }} = {{ value }} then {{ value_column }} else 0 end) as "{{ value }}"
  {%- if not loop.last %},{% endif %}
  {% endfor %}
{% endmacro %}
