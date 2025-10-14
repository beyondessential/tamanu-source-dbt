with base as (
    select count(*) as total_encounters
    from {{ ref('encounters') }} e
    join {{ ref('locations') }} l
        on l.id = e.location_id
    join {{ ref('facilities') }} f
        on f.id = l.facility_id
    where not f.is_sensitive
),
dataset as (
    select count(*) as total_encounters
    from {{ ref('ds__user_audit') }}
)
select base.total_encounters as base_total_encounters,
       dataset.total_encounters as dataset_total_encounters
from base
join dataset on dataset.total_encounters != base.total_encounters