{#- Body of `encounter_prescriptions` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro encounter_prescriptions_base(network=none) -%}
select
    ep.id,
    ep.encounter_id,
    ep.prescription_id,
    ep.is_selected_for_discharge,
    ep.updated_at_sync_tick
from {{ source('tamanu', 'encounter_prescriptions') }} ep
join {{ source('tamanu', 'encounters') }} e on e.id = ep.encounter_id
where ep.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    -- BL-005: the row follows its encounter's partition
    and {{ location_id_in_partition('e.location_id', network) }}
{%- if is_incremental() %}
    and ep.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
