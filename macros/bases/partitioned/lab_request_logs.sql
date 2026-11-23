{#- Body of `lab_request_logs` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro lab_request_logs_base(network=none) -%}
select
    lrl.id,
    lrl.created_at at time zone '{{ var("timezone") }}' as created_datetime,
    lrl.updated_at at time zone '{{ var("timezone") }}' as updated_datetime,
    lrl.lab_request_id,
    lrl.status,
    lrl.updated_by_id,
    lrl.updated_at_sync_tick
from {{ source('tamanu', 'lab_request_logs') }} lrl
join {{ source('tamanu', 'lab_requests') }} lr on lr.id = lrl.lab_request_id
join {{ source('tamanu', 'encounters') }} e on e.id = lr.encounter_id
where lrl.deleted_at is null
    and lr.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    -- BL-005: the row follows its encounter's partition
    and {{ location_id_in_partition('e.location_id', network) }}
{%- if is_incremental() %}
    and lrl.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
