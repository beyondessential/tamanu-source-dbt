{#- Body of `pharmacy_orders` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro pharmacy_orders_base(network=none) -%}
select
    po.id,
    po.encounter_id,
    po.ordering_clinician_id,
    po.facility_id,
    po.is_discharge_prescription,
    po.date::timestamp as datetime,
    po.updated_at_sync_tick
from {{ source('tamanu', 'pharmacy_orders') }} po
join {{ source('tamanu', 'encounters') }} e on e.id = po.encounter_id
where po.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    -- BL-005: the row follows its encounter's partition
    and {{ location_id_in_partition('e.location_id', network) }}
{%- if is_incremental() %}
    and po.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
