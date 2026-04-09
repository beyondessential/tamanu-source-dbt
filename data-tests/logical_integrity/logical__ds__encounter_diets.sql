with base as (
    select count(*) as total_patients
    from {{ ref('encounters') }} e
    join {{ ref('locations') }} l
        on l.id = e.location_id
    join {{ ref('facilities') }} f
        on f.id = l.facility_id
        and not f.is_sensitive
    where e.end_datetime is null
),
dataset as (
    select count(*) as total_patients
    from {{ ref('ds__encounter_diets') }}
)
select base.total_patients as base_total_patients,
       dataset.total_patients as dataset_total_patients
from base
join dataset on dataset.total_patients != base.total_patients