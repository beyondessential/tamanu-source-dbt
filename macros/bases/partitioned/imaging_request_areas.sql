{#- Body of `imaging_request_areas` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro imaging_request_areas_base(network=none) -%}
select
    ira.id,
    ira.imaging_request_id,
    ira.area_id,
    ira.updated_at_sync_tick
from {{ source('tamanu', 'imaging_request_areas') }} ira
join {{ source('tamanu', 'imaging_requests') }} ir on ir.id = ira.imaging_request_id
join {{ source('tamanu', 'encounters') }} e on e.id = ir.encounter_id
where ira.deleted_at is null
    and ir.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    -- BL-005: the row follows its encounter's partition
    and {{ location_id_in_partition('e.location_id', network) }}
{%- if is_incremental() %}
    and ira.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
