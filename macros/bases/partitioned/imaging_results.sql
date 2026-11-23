{#- Body of `imaging_results` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro imaging_results_base(network=none) -%}
select
    ires.id,
    ires.completed_at::timestamp as datetime,
    ires.description,
    ires.imaging_request_id,
    ires.external_code,
    ires.completed_by_id,
    ires.visibility_status,
    ires.updated_at_sync_tick
from {{ source('tamanu', 'imaging_results') }} ires
join {{ source('tamanu', 'imaging_requests') }} ireq on ireq.id = ires.imaging_request_id
join {{ source('tamanu', 'encounters') }} e on e.id = ireq.encounter_id
where ires.deleted_at is null
    and ireq.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    -- BL-005: the row follows its encounter's partition
    and {{ location_id_in_partition('e.location_id', network) }}
{%- if is_incremental() %}
    and ires.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
