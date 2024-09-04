{% test valid_discharge_disposition(model, column_name, type) %}
SELECT m.*
FROM {{ model }} m
LEFT JOIN reference_data rd ON rd.id = m.{{ column_name }} AND rd.type = 'dischargeDisposition'
WHERE m.{{ column_name }} NOTNULL
    AND rd.id IS NULL
{% endtest %}