{#- Body of `patients_access_logs` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro patients_access_logs_base(network=none) -%}
select
    id,
    user_id,
    record_id as patient_id,
    facility_id,
    logged_at at time zone '{{ var("timezone") }}' as logged_at,
    session_id,
    device_id,
    is_mobile,
    version,
    front_end_context,
    back_end_context,
    updated_at_sync_tick
from {{ source("logs__tamanu", "accesses") }}
where deleted_at is null
    and record_type = 'Patient'
    -- BL-001: the facility the record was viewed at decides the partition
    and {{ facility_id_in_partition('facility_id', network) }}
{%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
