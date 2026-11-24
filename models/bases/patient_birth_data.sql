{{ incremental_from_table(
    key='patient_id',
    table='patient_birth_data'
) }}
select
    patient_id,
    time_of_birth::time as birth_time,
    gestational_age_estimate,
    attendant_at_birth,
    name_of_attendant_at_birth,
    birth_type,
    birth_delivery_type,
    birth_weight,
    birth_length,
    apgar_score_one_minute,
    apgar_score_five_minutes,
    apgar_score_ten_minutes,
    registered_birth_place,
    birth_facility_id,
    (created_at at time zone '{{ var("timezone") }}')::date as registration_date,
    updated_at_sync_tick
from {{ source('tamanu', 'patient_birth_data') }}
where deleted_at is null
    and id != '{{ var("test_patient") }}'
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
