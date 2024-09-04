SELECT n.id
FROM {{ source("tamanu", "discharges") }} d
LEFT JOIN {{ source("tamanu", "notes") }} n ON n.record_id = d.encounter_id
    AND n.content = d.note
WHERE n.id IS NULL
