{% test valid_visibility_status(model, column_name) %}
SELECT *
FROM {{ model }}
WHERE {{ column_name }} NOT IN ('current', 'historical', 'merged')
{% endtest %}