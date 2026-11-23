{#- Body of `imaging_requests` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro imaging_requests_base(network=none) -%}
select
    ir.id,
    ir.display_id,
    ir.requested_date::timestamp as datetime,
    ir.status,
    ir.priority,
    ir.imaging_type,
    ir.encounter_id,
    ir.requested_by_id,
    ir.completed_by_id,
    ir.location_id,
    ir.location_group_id,
    ir.reason_for_cancellation,
    ir.updated_at_sync_tick
from {{ source('tamanu', 'imaging_requests') }} ir
join {{ source('tamanu', 'encounters') }} e on e.id = ir.encounter_id
where ir.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    -- BL-005: the row follows its encounter's partition
    and {{ location_id_in_partition('e.location_id', network) }}
{%- if is_incremental() %}
    and ir.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
