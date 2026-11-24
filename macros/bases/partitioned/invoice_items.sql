{#- Body of `invoice_items` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro invoice_items_base(network=none) -%}
select
    ii.id,
    ii.invoice_id,
    ii.order_date::date as date,
    ii.product_id,
    ii.product_code_final,
    ii.product_name_final,
    ii.price_final,
    ii.is_fixed_price_final,
    ii.manual_entry_price,
    ii.quantity,
    ii.ordered_by_user_id,
    ii.approved,
    ii.source_record_type,
    ii.source_record_id,
    ii.updated_at_sync_tick
from {{ source('tamanu', 'invoice_items') }} ii
join {{ source('tamanu', 'invoices') }} i on i.id = ii.invoice_id
join {{ source('tamanu', 'encounters') }} e on e.id = i.encounter_id
where
    ii.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    -- BL-005: the row follows its encounter's partition
    and {{ location_id_in_partition('e.location_id', network) }}
{%- if is_incremental() %}
    and ii.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
