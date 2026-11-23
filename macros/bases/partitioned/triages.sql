{#- Body of `triages` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro triages_base(network=none) -%}
select
    t.id,
    t.arrival_time::timestamp as arrival_datetime,
    t.triage_time::timestamp as triage_datetime,
    t.closed_time::timestamp as closed_datetime,
    t.arrival_mode_id,
    t.score,
    t.encounter_id,
    t.practitioner_id as clinician_id,
    t.chief_complaint_id,
    t.secondary_complaint_id,
    t.updated_at_sync_tick
from {{ source('tamanu', 'triages') }} t
join {{ source('tamanu', 'encounters') }} e on e.id = t.encounter_id
where t.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    -- BL-005: the row follows its encounter's partition
    and {{ location_id_in_partition('e.location_id', network) }}
{%- if is_incremental() %}
    and t.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
