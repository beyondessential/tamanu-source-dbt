{#- Body of `survey_response_answers` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro survey_response_answers_base(network=none) -%}
select
    id,
    name,
    body,
    response_id,
    data_element_id,
    updated_at_sync_tick
from {{ source('tamanu', 'survey_response_answers') }}
where deleted_at is null
    -- BL-005: the answer follows its response's encounter
    and {{ encounter_id_in_partition("(select psr.encounter_id from " ~ source('tamanu', 'survey_responses') ~ " psr where psr.id = response_id)", network) }}
{%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
