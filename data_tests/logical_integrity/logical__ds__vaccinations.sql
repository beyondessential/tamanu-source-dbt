with base as (
    select count(*) as total_vaccinations
    from {{ ref('vaccine_administrations') }} va
    join {{ ref('encounters') }} e
        on e.id = va.encounter_id
    join {{ ref('locations') }} l
        on l.id = e.location_id
    join {{ ref('facilities') }} f
        on f.id = l.facility_id
    where not f.is_sensitive
),
dataset as (
    select count(*) as total_vaccinations
    from {{ ref('ds__vaccinations') }}
)
select base.total_vaccinations as base_total_vaccinations,
       dataset.total_vaccinations as dataset_total_vaccinations
from base
join dataset on dataset.total_vaccinations != base.total_vaccinations