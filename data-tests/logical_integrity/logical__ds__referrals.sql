with base as (
    select count(*) as total_referrals
    from {{ ref('referrals') }} r
    join {{ ref('encounters') }} e
        on e.id = r.initiating_encounter_id
    join {{ ref('locations') }} l
        on l.id = e.location_id
    join {{ ref('facilities') }} f
        on f.id = l.facility_id
    where not f.is_sensitive
),
dataset as (
    select count(*) as total_referrals
    from {{ ref('ds__referrals') }}
)
select base.total_referrals as base_total_referrals,
       dataset.total_referrals as dataset_total_referrals
from base
join dataset on dataset.total_referrals != base.total_referrals