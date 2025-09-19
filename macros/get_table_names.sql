{% macro get_table_names() %}
  {% set query %}
    select distinct table_name 
    from {{ source('logs__tamanu', 'changes') }} 
    order by table_name
  {% endset %}

  {% if execute %}
    {% set results = run_query(query) %}
    {% set table_names = results.columns[0].values() %}
    {% for table_name in table_names %}
      {{ print(table_name) }}
    {% endfor %}
  {% endif %}
{% endmacro %}
