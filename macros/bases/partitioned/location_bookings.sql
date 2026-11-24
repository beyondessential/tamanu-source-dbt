{#- Body of `location_bookings` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro location_bookings_base(network=none) -%}
select
    id,
    start_time::timestamp as start_datetime,
    end_time::timestamp as end_datetime,
    patient_id,
    clinician_id,
    encounter_id,
    location_id,
    booking_type_id,
    is_high_priority,
    status,
    updated_at_sync_tick
from {{ source('tamanu', 'appointments') }}
where booking_type_id notnull
    and deleted_at is null
    and patient_id != '{{ var("test_patient") }}'
    -- BL-001: the booked location's facility decides the partition
    and {{ location_id_in_partition('location_id', network) }}
{%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
