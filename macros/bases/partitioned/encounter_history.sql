{#- Body of `encounter_history` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro encounter_history_base(network=none) -%}
select
    eh.id,
    eh.date::timestamp as datetime,
    eh.encounter_id,
    eh.department_id,
    eh.location_id,
    eh.encounter_type,
    eh.examiner_id as clinician_id,
    eh.actor_id as updated_by_id,
    eh.change_type::text[],
    eh.updated_at_sync_tick
from {{ source('tamanu', 'encounter_history') }} eh
join {{ source('tamanu', 'encounters') }} e on e.id = eh.encounter_id
where eh.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    -- BL-005: the row follows its encounter's partition
    and {{ location_id_in_partition('e.location_id', network) }}
{%- if is_incremental() %}
    and eh.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
