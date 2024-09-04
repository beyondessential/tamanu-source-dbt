{% test valid_diagnosis(model, column_name, type) %}
SELECT m.*
FROM {{ model }} m
LEFT JOIN reference_data rd ON rd.id = m.{{ column_name }} AND rd.type = 'icd10'
WHERE m.{{ column_name }} NOTNULL
    AND rd.id IS NULL
{% endtest %}