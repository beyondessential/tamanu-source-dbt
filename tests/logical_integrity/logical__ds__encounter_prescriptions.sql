with base as (
    select count(*) as total_prescriptions
    from {{ ref('encounter_prescriptions') }} ep
    join {{ ref('encounters') }} e
        on e.id = ep.encounter_id
    join {{ ref('locations') }} l
        on l.id = e.location_id
    join {{ ref('facilities') }} f
        on f.id = l.facility_id
    where not f.is_sensitive
),
dataset as (
    select count(*) as total_prescriptions
    from {{ ref('ds__encounter_prescriptions') }}
)
select base.total_prescriptions as base_total_prescriptions,
       dataset.total_prescriptions as dataset_total_prescriptions
from base
join dataset on dataset.total_prescriptions != base.total_prescriptions