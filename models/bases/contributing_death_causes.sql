select
    id,
    time_after_onset,
    patient_death_data_id,
    condition_id,
    created_at
from {{ source("tamanu", "contributing_death_causes") }}
where deleted_at is null