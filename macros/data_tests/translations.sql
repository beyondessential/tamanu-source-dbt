{% macro translate_string(string_id, language='en') %}
    {% set query %}
        select text
        from {{ source('tamanu', 'translated_strings') }}
        where string_id = '{{ string_id }}'
            and language = '{{ language }}'
    {% endset %}
    {% set result = run_query(query) %}
    {% if execute %}
        {{ result.columns[0].values()[0] }}
    {% endif %}
{% endmacro %}
