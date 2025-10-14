with base as (
    select count(*) as total_diagnoses
    from {{ ref('encounter_diagnoses') }} ed
    join {{ ref('encounters') }} e
        on e.id = ed.encounter_id
    join {{ ref('locations') }} l
        on l.id = e.location_id
    join {{ ref('facilities') }} f
        on f.id = l.facility_id
    where not f.is_sensitive
),
dataset as (
    select count(*) as total_diagnoses
    from {{ ref('ds__diagnoses') }}
)
select base.total_diagnoses as base_total_diagnoses,
       dataset.total_diagnoses as dataset_total_diagnoses
from base
join dataset on dataset.total_diagnoses != base.total_diagnoses