{#- Body of `invoice_patient_payments` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro invoice_patient_payments_base(network=none) -%}
select
    ipp.id,
    ipp.invoice_payment_id,
    ipp.method_id,
    ipp.cheque_number,
    ipp.updated_at_sync_tick
from {{ source('tamanu', 'invoice_patient_payments') }} ipp
join {{ source('tamanu', 'invoice_payments') }} ipay on ipay.id = ipp.invoice_payment_id
join {{ source('tamanu', 'invoices') }} i on i.id = ipay.invoice_id
join {{ source('tamanu', 'encounters') }} e on e.id = i.encounter_id
where
    ipp.deleted_at is null
    and ipay.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    -- BL-005: the row follows its encounter's partition
    and {{ location_id_in_partition('e.location_id', network) }}
{%- if is_incremental() %}
    and ipp.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
