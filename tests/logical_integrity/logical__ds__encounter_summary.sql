with base as (
    select count(*) as total_encounters
    from {{ ref('encounters') }} e
    join {{ ref('locations') }} l
        on l.id = e.location_id
    join {{ ref('facilities') }} f
        on f.id = l.facility_id
    where not f.is_sensitive
        and e.end_datetime is not null
),
dataset as (
    select count(*) as total_encounters
    from {{ ref('ds__encounter_summary') }}
)
select base.total_encounters as base_total_encounters,
       dataset.total_encounters as dataset_total_encounters
from base
join dataset on dataset.total_encounters != base.total_encounters