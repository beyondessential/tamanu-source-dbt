{#- Body of `medication_dispenses` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro medication_dispenses_base(network=none) -%}
select
    md.id,
    md.pharmacy_order_prescription_id,
    md.quantity,
    md.dispensed_at::timestamp as dispensed_at,
    md.dispensed_by_user_id,
    md.medication_id,
    md.route,
    md.updated_at_sync_tick
from {{ source('tamanu', 'medication_dispenses') }} md
join {{ source('tamanu', 'pharmacy_order_prescriptions') }} pop
    on pop.id = md.pharmacy_order_prescription_id
join {{ source('tamanu', 'pharmacy_orders') }} po on po.id = pop.pharmacy_order_id
join {{ source('tamanu', 'encounters') }} e on e.id = po.encounter_id
where md.deleted_at is null
    and pop.deleted_at is null
    and po.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    -- BL-005: the row follows its encounter's partition
    and {{ location_id_in_partition('e.location_id', network) }}
{%- if is_incremental() %}
    and md.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
