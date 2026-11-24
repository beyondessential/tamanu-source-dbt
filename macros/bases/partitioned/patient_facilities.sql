{#- Body of `patient_facilities` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro patient_facilities_base(network=none) -%}
select
    id,
    created_at at time zone '{{ var("timezone") }}' as created_at,
    patient_id,
    facility_id,
    updated_at_sync_tick
from {{ source('tamanu', 'patient_facilities') }}
where deleted_at is null
    and patient_id != '{{ var("test_patient") }}'
    -- BL-001: the facility decides the row's partition
    and {{ facility_id_in_partition('facility_id', network) }}
{%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
