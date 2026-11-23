{#- Body of `lab_requests` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro lab_requests_base(network=none) -%}
select
    lr.id,
    lr.created_at at time zone '{{ var("timezone") }}' as created_datetime,
    lr.updated_at at time zone '{{ var("timezone") }}' as updated_datetime,
    lr.display_id,
    lr.urgent as is_urgent,
    lr.status,
    lr.requested_date::timestamp as requested_datetime,
    lr.lab_test_priority_id,
    lr.lab_test_category_id,
    lr.lab_test_laboratory_id,
    lr.requested_by_id,
    lr.specimen_attached as is_specimen_collected,
    lr.specimen_type_id,
    lr.lab_sample_site_id,
    lr.sample_time::timestamp as collected_datetime,
    lr.collected_by_id,
    lr.reason_for_cancellation,
    lr.published_date::timestamp as published_datetime,
    lr.encounter_id,
    lr.department_id,
    lr.updated_at_sync_tick
from {{ source('tamanu', 'lab_requests') }} lr
join {{ source('tamanu', 'encounters') }} e on e.id = lr.encounter_id
where lr.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    -- BL-005: the row follows its encounter's partition
    and {{ location_id_in_partition('e.location_id', network) }}
{%- if is_incremental() %}
    and lr.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
