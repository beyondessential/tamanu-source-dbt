{#- Body of `encounter_diets` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro encounter_diets_base(network=none) -%}
select
    ed.id,
    ed.encounter_id,
    ed.diet_id,
    ed.created_at at time zone '{{ var("timezone") }}' as created_datetime,
    ed.updated_at_sync_tick
from {{ source('tamanu', 'encounter_diets') }} ed
join {{ source('tamanu', 'encounters') }} e on e.id = ed.encounter_id
where ed.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    -- BL-005: the row follows its encounter's partition
    and {{ location_id_in_partition('e.location_id', network) }}
{%- if is_incremental() %}
    and ed.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
