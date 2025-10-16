with base as (
    select count(*) as total_admissions
    from {{ ref('encounters') }} e
    join {{ ref('locations') }} l
        on l.id = e.location_id
    join {{ ref('facilities') }} f
        on f.id = l.facility_id
    where not f.is_sensitive
        and e.encounter_type = 'admission'
),
dataset as (
    select count(*) as total_admissions
    from {{ ref('ds__admissions') }}
)
select base.total_admissions as base_total_admissions,
       dataset.total_admissions as dataset_total_admissions
from base
join dataset on dataset.total_admissions != base.total_admissions