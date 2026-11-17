-- ref__location -- OMOP LOCATION: one row per patient address, the combination of village,
-- subdivision and division a patient resolves to in int__patient_address, with each level's
-- name and id written onto the row.
-- See specs/dbt-model/ref__location.md for the BL clauses this model implements.

with addresses as (
    select distinct
        location_id,
        village_id,
        subdivision_id,
        division_id,
        country_id
    from {{ ref('int__patient_address') }}
    where location_id is not null
),

places as (
    select
        id,
        name
    from {{ ref('reference_data') }}
)

-- BL-008: one row per address, carrying the names and ids of its levels
select
    a.location_id,
    a.location_id as location_source_value,
    v.name as city,
    sd.name as county,
    d.name as state,
    c.name as country_source_value,
    a.village_id,
    a.subdivision_id,
    a.division_id,
    a.country_id
from addresses a
left join places v on v.id = a.village_id
left join places sd on sd.id = a.subdivision_id
left join places d on d.id = a.division_id
left join places c on c.id = a.country_id
