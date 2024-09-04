SELECT rd.id
FROM {{ source("tamanu", "patients") }} p
LEFT JOIN {{ source("tamanu", "reference_data") }} rd ON rd.id = p.village_id
WHERE p.village_id IS NOT NULL
    AND rd.id IS NULL
