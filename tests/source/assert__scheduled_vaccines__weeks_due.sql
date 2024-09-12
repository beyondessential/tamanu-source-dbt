SELECT
    category,
    vaccine_id
FROM {{ source("tamanu", "scheduled_vaccines") }}
WHERE weeks_from_birth_due notnull
    AND index != 1
    AND visibility_status = 'current'
GROUP BY
    category,
    vaccine_id

UNION

SELECT
    category,
    vaccine_id
FROM {{ source("tamanu", "scheduled_vaccines") }}
WHERE weeks_from_last_vaccination_due notnull
    AND index = 1
    AND visibility_status = 'current'
GROUP BY
    category,
    vaccine_id