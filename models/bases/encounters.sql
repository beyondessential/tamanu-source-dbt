select
    id,
    start_date::timestamp as start_datetime,
    case
        when end_date < start_date then start_date::timestamp
        else end_date::timestamp
    end as end_datetime,
    encounter_type,
    reason_for_encounter,
    device_id,
    patient_id,
    department_id,
    location_id,
    examiner_id as clinician_id,
    patient_billing_type_id,
    referral_source_id,
    planned_location_id,
    planned_location_start_time::timestamp as planned_location_start_datetime,
    discharge_draft
from {{ source('tamanu', 'encounters') }}
where deleted_at is null
    and patient_id != '{{ var("test_patient") }}'
