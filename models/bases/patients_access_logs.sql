select
    id,
    user_id,
    record_id as patient_id,
    facility_id,
    logged_at,
    session_id,
    device_id,
    is_mobile,
    version,
    front_end_context,
    back_end_context
from {{ source("logs__tamanu", "accesses") }}
where deleted_at is null
    and record_type = 'Patient'
    and record_id is not null
    and user_id is not null
