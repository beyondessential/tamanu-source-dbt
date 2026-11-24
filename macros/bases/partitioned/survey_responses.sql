{#- Body of `survey_responses` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro survey_responses_base(network=none) -%}
select
    id,
    start_time::timestamp as start_datetime,
    end_time::timestamp as end_datetime,
    result_text,
    notified as is_notified,
    survey_id,
    encounter_id,
    user_id as submitted_by_id,
    updated_at_sync_tick
from {{ source('tamanu', 'survey_responses') }}
where deleted_at is null
    -- BL-005: the response follows its encounter's partition
    and {{ encounter_id_in_partition('encounter_id', network) }}
{%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
