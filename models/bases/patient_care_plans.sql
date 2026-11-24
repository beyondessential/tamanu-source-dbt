{{ incremental_from_table(
    key='id',
    table='patient_care_plans'
) }}
select
    id,
    date::timestamp as care_plan_datetime,
    patient_id,
    examiner_id as clinician_id,
    care_plan_id,
    updated_at_sync_tick
from {{ source('tamanu', 'patient_care_plans') }}
where deleted_at is null
    and patient_id != '{{ var("test_patient") }}'
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
