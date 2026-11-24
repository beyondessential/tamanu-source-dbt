{#- Body of `invoice_payments` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro invoice_payments_base(network=none) -%}
select
    ipay.id,
    ipay.invoice_id,
    ipay.date::date,
    ipay.receipt_number,
    ipay.amount,
    ipay.original_payment_id,
    ipay.updated_at_sync_tick
from {{ source('tamanu', 'invoice_payments') }} ipay
join {{ source('tamanu', 'invoices') }} i on i.id = ipay.invoice_id
join {{ source('tamanu', 'encounters') }} e on e.id = i.encounter_id
where
    ipay.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    -- BL-005: the row follows its encounter's partition
    and {{ location_id_in_partition('e.location_id', network) }}
{%- if is_incremental() %}
    and ipay.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
