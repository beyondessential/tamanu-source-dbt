{#- Body of `lab_test_panel_requests` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro lab_test_panel_requests_base(network=none) -%}
select
    ltpr.id,
    ltpr.lab_test_panel_id,
    ltpr.encounter_id,
    ltpr.lab_request_id,
    ltpr.updated_at_sync_tick
from {{ source('tamanu', 'lab_test_panel_requests') }} ltpr
join {{ source('tamanu', 'encounters') }} e on e.id = ltpr.encounter_id
where ltpr.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    -- BL-005: the row follows its encounter's partition
    and {{ location_id_in_partition('e.location_id', network) }}
{%- if is_incremental() %}
    and ltpr.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
