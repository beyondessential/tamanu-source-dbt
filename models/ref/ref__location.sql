-- ref__location -- OMOP LOCATION: one row per location patients are grouped under in
-- int__patient_address, with the name and id of each place the location covers.
-- See specs/dbt-model/ref__location.md for the BL clauses this model implements.

with locations as (
    select distinct
        location_id,
        location_source_value,
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

-- BL-005: one row per location, carrying the names and ids of the places it covers
select
    l.location_id,
    l.location_source_value,
    v.name as city,
    sd.name as county,
    d.name as state,
    c.name as country_source_value,
    l.village_id,
    l.subdivision_id,
    l.division_id,
    l.country_id
from locations l
left join places v on v.id = l.village_id
left join places sd on sd.id = l.subdivision_id
left join places d on d.id = l.division_id
left join places c on c.id = l.country_id
