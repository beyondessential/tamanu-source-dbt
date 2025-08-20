{% macro get_survey_columns(survey_id) %}
    SELECT 
        replace(concat(ssc.survey_id, '_', pde.code), '-', '_') as id, 
        replace(pde.code,'-','_') as code,
        pde.name 
    FROM {{ source('tamanu', 'survey_screen_components') }} ssc
    JOIN {{ source('tamanu', 'program_data_elements') }} pde
    ON ssc.data_element_id = pde.id
    WHERE ssc.survey_id = '{{ survey_id }}'
    AND ssc.deleted_at IS null
    AND pde.type != 'Instruction'
    AND pde.deleted_at IS NULL
    ORDER BY ssc.screen_index, ssc.component_index
{% endmacro %}

{% macro get_survey(survey_id) %}
    {%- set query = get_survey_columns(survey_id) -%}
    {%- set columns = dbt_utils.get_query_results_as_dict(query) -%}
    SELECT 
        sr.encounter_id,
        sra.response_id, 
        e.patient_id,
        sr.start_datetime,
        sr.end_datetime,
        sr.result_text
    {%- for id, code in zip(columns['id'], columns['code']) %},
            MAX(CASE WHEN sra.data_element_id = '{{ id }}' THEN NULLIF(sra.body,'') END) AS "{{ code }}"
    {% endfor %}
    FROM {{ ref('survey_responses') }} sr 
    JOIN {{ ref('survey_response_answers') }} sra 
    ON sra.response_id = sr.id
    JOIN {{ ref('encounters')}} e
    ON e.id = sr.encounter_id
    WHERE sr.survey_id = '{{ survey_id }}'
    GROUP BY sra.response_id, sr.encounter_id, sr.start_datetime, sr.end_datetime, sr.result_text, e.patient_id
{% endmacro %}

{% macro get_surveys_list() %}
    {% set query %}
        SELECT 
            id,
            name
        FROM {{ source('tamanu', 'surveys') }}
        WHERE deleted_at IS NULL
        AND visibility_status = 'current'
    {% endset %}
    
    {% set results = run_query(query) %}
    
    {% if execute %}
        {% for row in results %}
            {{ log("SURVEY_DATA:" ~ row[0] ~ "|" ~ row[1], info=true) }}
        {% endfor %}
    {% endif %}
{% endmacro %} 

{% macro get_survey_docs(survey_id) %}
    {%- set query = get_survey_columns(survey_id) -%}
    {% set results = run_query(query) %}
    
    {% if execute %}
        {% for row in results %}
            {{ log("COLUMN_DATA:" ~ row[0] ~ "|" ~ row[1] ~ "|" ~ row[2], info=true) }}
        {% endfor %}
    {% endif %}
{% endmacro %}