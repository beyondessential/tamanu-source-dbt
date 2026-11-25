{#- Body of `invoice_insurance_plan_payments` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro invoice_insurance_plan_payments_base(network=none) -%}
select
    iipp.id,
    iipp.invoice_payment_id,
    iipp.invoice_insurance_plan_id,
    iipp.status,
    iipp.reason,
    iipp.updated_at_sync_tick
from {{ source('tamanu', 'invoice_insurance_plan_payments') }} iipp
join {{ source('tamanu', 'invoice_payments') }} ipay on ipay.id = iipp.invoice_payment_id
join {{ source('tamanu', 'invoices') }} i on i.id = ipay.invoice_id
join {{ source('tamanu', 'encounters') }} e on e.id = i.encounter_id
where
    iipp.deleted_at is null
    and ipay.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    -- BL-005: the row follows its encounter's partition
    and {{ location_id_in_partition('e.location_id', network) }}
{%- if is_incremental() %}
    and iipp.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
