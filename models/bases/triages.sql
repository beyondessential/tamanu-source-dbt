select
    id,
    arrival_time::timestamp as arrival_datetime,
    triage_time::timestamp as triage_datetime,
    closed_time::timestamp as closed_datetime,
    arrival_mode_id,
    score,
    encounter_id,
    practitioner_id as clinician_id,
    chief_complaint_id,
    secondary_complaint_id
from {{ resolve_input_model('triages') }}
where deleted_at is null
