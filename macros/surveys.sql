{% macro get_survey_columns(survey_id) %}
    {#- Questions of one survey, or of every survey when survey_id is none -#}
    SELECT
        ssc.survey_id,
        pde.id,
        replace(pde.code,'-','_') as code,
        pde.name
    FROM {{ source('tamanu', 'survey_screen_components') }} ssc
    JOIN {{ source('tamanu', 'program_data_elements') }} pde
    ON ssc.data_element_id = pde.id
    WHERE ssc.deleted_at IS null
    AND pde.type != 'Instruction'
    AND pde.deleted_at IS NULL
    {%- if survey_id is not none %}
    AND ssc.survey_id = '{{ survey_id }}'
    {%- endif %}
    ORDER BY ssc.survey_id, ssc.screen_index, ssc.component_index
{% endmacro %}

{% macro get_survey(survey_id) %}
    {%- set query = get_survey_columns(survey_id) -%}
    {%- set columns = dbt_utils.get_query_results_as_dict(query) -%}
    {%- set reserved = ['encounter_id', 'response_id', 'patient_id',
                        'start_datetime', 'end_datetime', 'result_text'] -%}
    SELECT
        sr.encounter_id,
        sra.response_id,
        e.patient_id,
        sr.start_datetime,
        sr.end_datetime,
        sr.result_text
    {%- for id, code in zip(columns['id'], columns['code']) %}
        {%- set alias = (code ~ '_answer') if code in reserved else code %},
            MAX(CASE WHEN sra.data_element_id = '{{ id }}' THEN NULLIF(sra.body,'') END) AS "{{ alias }}"
    {% endfor %}
    FROM {{ ref('survey_responses') }} sr 
    JOIN {{ ref('survey_response_answers') }} sra 
    ON sra.response_id = sr.id
    JOIN {{ ref('encounters')}} e
    ON e.id = sr.encounter_id
    WHERE sr.survey_id = '{{ survey_id }}'
    GROUP BY sra.response_id, sr.encounter_id, sr.start_datetime, sr.end_datetime, sr.result_text, e.patient_id
{% endmacro %}

{% macro get_all_survey_docs() %}
    {#- Lists every current survey and every survey's questions in one call, for generate_survey_models.py -#}
    {% set surveys_query %}
        SELECT
            id,
            name
        FROM {{ source('tamanu', 'surveys') }}
        WHERE deleted_at IS NULL
        AND visibility_status = 'current'
        ORDER BY id
    {% endset %}

    {% set surveys = run_query(surveys_query) %}
    {% set columns = run_query(get_survey_columns(none)) %}

    {#- Each row is logged as a JSON array, so a name holding a delimiter or a newline reads back whole -#}
    {% if execute %}
        {% for row in surveys %}
            {{ log("SURVEY_DATA:" ~ tojson([row[0], row[1]]), info=true) }}
        {% endfor %}
        {% for row in columns %}
            {{ log("COLUMN_DATA:" ~ tojson([row[0], row[1], row[2], row[3]]), info=true) }}
        {% endfor %}
    {% endif %}
{% endmacro %}
