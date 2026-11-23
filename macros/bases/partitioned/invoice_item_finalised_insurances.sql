{#- Body of `invoice_item_finalised_insurances` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro invoice_item_finalised_insurances_base(network=none) -%}
select
    iifi.id,
    iifi.invoice_item_id,
    iifi.invoice_insurance_plan_id,
    iifi.coverage_value_final,
    iifi.updated_at_sync_tick
from {{ source('tamanu', 'invoice_item_finalised_insurances') }} iifi
join {{ source('tamanu', 'invoice_items') }} ii on ii.id = iifi.invoice_item_id
join {{ source('tamanu', 'invoices') }} i on i.id = ii.invoice_id
join {{ source('tamanu', 'encounters') }} e on e.id = i.encounter_id
where
    iifi.deleted_at is null
    and ii.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    -- BL-005: the row follows its encounter's partition
    and {{ location_id_in_partition('e.location_id', network) }}
{%- if is_incremental() %}
    and iifi.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
