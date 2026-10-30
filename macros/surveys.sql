{#- With a survey_id, that survey's question columns (used by get_survey).
    Without one, every survey's, led by survey_id -- one query for the lot, so
    the model generator needs a single dbt call rather than one per survey. -#}
{% macro get_survey_columns(survey_id=none) %}
    SELECT 
        {% if survey_id is none %}ssc.survey_id,{% endif %}
        pde.id, 
        replace(pde.code,'-','_') as code,
        pde.name 
    FROM {{ source('tamanu', 'survey_screen_components') }} ssc
    JOIN {{ source('tamanu', 'program_data_elements') }} pde
    ON ssc.data_element_id = pde.id
    WHERE ssc.deleted_at IS null
    {% if survey_id is not none %}AND ssc.survey_id = '{{ survey_id }}'{% endif %}
    AND pde.type != 'Instruction'
    AND pde.deleted_at IS NULL
    ORDER BY {% if survey_id is none %}ssc.survey_id, {% endif %}ssc.screen_index, ssc.component_index
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

{#- Every current survey and all of their question columns, logged as one
    JSON payload for scripts/generate_survey_models.py. JSON rather than
    delimited lines so a name holding '|' or a line break survives intact. -#}
{% macro get_all_survey_docs() %}
    {% set surveys_query %}
        SELECT 
            id,
            name
        FROM {{ source('tamanu', 'surveys') }}
        WHERE deleted_at IS NULL
        AND visibility_status = 'current'
        ORDER BY id
    {% endset %}

    {% if execute %}
        {% set surveys = [] %}
        {% for row in run_query(surveys_query) %}
            {% do surveys.append([row[0], row[1]]) %}
        {% endfor %}

        {% set columns = [] %}
        {% for row in run_query(get_survey_columns()) %}
            {% do columns.append([row[0], row[1], row[2], row[3]]) %}
        {% endfor %}

        {{ log("SURVEY_DOCS_JSON:" ~ tojson({"surveys": surveys, "columns": columns}), info=true) }}
    {% endif %}
{% endmacro %}
