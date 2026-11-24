{#- Body of `invoices` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro invoices_base(network=none) -%}
select
    i.id,
    i.display_id,
    i.date::timestamp as datetime,
    i.status,
    i.patient_payment_status,
    i.insurer_payment_status,
    i.encounter_id,
    i.updated_at_sync_tick
from {{ source('tamanu', 'invoices') }} i
join {{ source('tamanu', 'encounters') }} e on e.id = i.encounter_id
where
    i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    -- BL-005: the row follows its encounter's partition
    and {{ location_id_in_partition('e.location_id', network) }}
{%- if is_incremental() %}
    and i.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
