SELECT u.role
FROM {{ source("tamanu", "users") }} u
LEFT JOIN {{ source("tamanu", "roles") }} r ON r.id = u.role
WHERE r.id IS NULL
    AND u.role NOT IN ('admin', 'practitioner')
