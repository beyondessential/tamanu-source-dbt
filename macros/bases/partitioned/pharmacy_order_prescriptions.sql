{#- Body of `pharmacy_order_prescriptions` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro pharmacy_order_prescriptions_base(network=none) -%}
select
    pop.id,
    pop.pharmacy_order_id,
    pop.prescription_id,
    pop.ongoing_prescription_id,
    pop.display_id,
    pop.quantity,
    pop.repeats,
    pop.is_completed,
    pop.updated_at_sync_tick
from {{ source('tamanu', 'pharmacy_order_prescriptions') }} pop
join {{ source('tamanu', 'pharmacy_orders') }} po on po.id = pop.pharmacy_order_id
join {{ source('tamanu', 'encounters') }} e on e.id = po.encounter_id
where pop.deleted_at is null
    and po.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    -- BL-005: the row follows its encounter's partition
    and {{ location_id_in_partition('e.location_id', network) }}
{%- if is_incremental() %}
    and pop.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
