SELECT d.*
FROM {{ source("tamanu", "discharges") }} d
JOIN {{ source("tamanu", "encounters") }} e ON e.id = d.encounter_id
JOIN {{ source("tamanu", "locations") }} l ON l.id = e.location_id
JOIN {{ source("tamanu", "facilities") }} f ON f.id = l.facility_id
WHERE (d.facility_name != f.name OR d.facility_name IS NULL)
    OR (d.facility_address != f.street_address OR d.facility_address IS NULL)
    OR (d.facility_town != f.city_town OR d.facility_town IS NULL)
