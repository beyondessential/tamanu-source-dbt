{% macro get_survey(survey_id) %}
    {% set sql_statement %}
        SELECT pde.id, pde.name, pde.code
        FROM {{ source(target.name, 'survey_screen_components') }} ssc
        JOIN {{ source(target.name, 'program_data_elements') }} pde
        ON ssc.data_element_id = pde.id
        WHERE ssc.survey_id = '{{survey_id}}'
        AND ssc.deleted_at IS null
        AND pde.type != 'Instruction'
    {% endset %}
    {%- set columns = dbt_utils.get_query_results_as_dict(sql_statement) -%}
    SELECT 
        sr.encounter_id,
        sr.survey_response_id, 
        sr.survey_response_submission_datetime,
        sr.result_text,
    {%- for id, code in zip(columns['id'], columns['code']) %}
            MAX(CASE WHEN sra.data_element_id = '{{ id }}' THEN NULLIF(value,'') END) AS "{{ code }}"{{"," if not loop.last}}
    {% endfor -%}
    FROM {{ ref('stg_tamanu__survey_responses') }} sr 
    JOIN {{ ref('stg_tamanu__survey_response_answers') }} sra 
    ON sra.survey_response_id = sr.survey_response_id
    WHERE survey_id = '{{ survey_id }}'
    GROUP BY sr.survey_response_id, sr.encounter_id, sr.survey_response_submission_datetime, sr.result_text
{% endmacro %}

{% macro get_surveys_list() %}
    {% set query %}
        select 
            id,
            name
        from {{ ref('surveys') }}
        where deleted_at is null
        and visibility_status = 'current'
        order by name
    {% endset %}
    
    {% set results = run_query(query) %}
    
    {% if execute %}
        {% for row in results %}
            {{ log("SURVEY_DATA:" ~ row[0] ~ "|" ~ row[1], info=false) }}
        {% endfor %}
    {% endif %}
{% endmacro %} 