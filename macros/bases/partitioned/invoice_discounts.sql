{#- Body of `invoice_discounts` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro invoice_discounts_base(network=none) -%}
select
    id.id,
    id.invoice_id,
    id.percentage,
    id.reason,
    id.is_manual,
    id.applied_by_user_id,
    id.applied_time,
    id.updated_at_sync_tick
from {{ source('tamanu', 'invoice_discounts') }} id
join {{ source('tamanu', 'invoices') }} i on i.id = id.invoice_id
join {{ source('tamanu', 'encounters') }} e on e.id = i.encounter_id
where
    id.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    -- BL-005: the row follows its encounter's partition
    and {{ location_id_in_partition('e.location_id', network) }}
{%- if is_incremental() %}
    and id.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
