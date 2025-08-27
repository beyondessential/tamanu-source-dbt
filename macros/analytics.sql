{% macro is_analytics_target() %}
  {{ return(target.name.startswith('analytics')) }}
{% endmacro %}
