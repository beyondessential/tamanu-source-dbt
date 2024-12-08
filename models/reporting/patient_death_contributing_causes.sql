SELECT
    cdc.id,
    time_after_onset AS mins_after_onset,
    patient_death_data_id,
    condition_id
FROM {{ source("tamanu", "contributing_death_causes") }} cdc
WHERE deleted_at IS NULL
