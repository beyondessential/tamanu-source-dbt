{#- Body of `lab_tests` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro lab_tests_base(network=none) -%}
select
    lt.id,
    lt.date::date as date,
    lt.result,
    lt.lab_request_id,
    lt.lab_test_panel_request_id,
    lt.lab_test_type_id,
    lt.lab_test_method_id,
    lt.laboratory_officer,
    lt.completed_date::timestamp as completed_datetime,
    lt.verification,
    lt.updated_at_sync_tick
from {{ source('tamanu', 'lab_tests') }} lt
join {{ source('tamanu', 'lab_requests') }} lr on lr.id = lt.lab_request_id
join {{ source('tamanu', 'encounters') }} e on e.id = lr.encounter_id
where lt.deleted_at is null
    and lr.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    -- BL-005: the row follows its encounter's partition
    and {{ location_id_in_partition('e.location_id', network) }}
{%- if is_incremental() %}
    and lt.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
