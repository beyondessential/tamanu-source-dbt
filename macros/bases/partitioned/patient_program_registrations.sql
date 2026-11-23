{#- Body of `patient_program_registrations` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro patient_program_registrations_base(network=none) -%}
select
    id,
    date::timestamp as datetime,
    registration_status,
    patient_id,
    program_registry_id,
    clinical_status_id,
    clinician_id as registered_by_id,
    registering_facility_id,
    facility_id,
    village_id,
    deactivated_clinician_id as deactivated_by_id,
    deactivated_date::timestamp as deactivated_datetime,
    updated_at_sync_tick
from {{ source('tamanu', 'patient_program_registrations') }}
where deleted_at is null
    and patient_id != '{{ var("test_patient") }}'
    -- BL-001, BL-003: the registering facility decides the partition, standard when there is none
    and {{ facility_id_in_partition('registering_facility_id', network) }}
{%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
