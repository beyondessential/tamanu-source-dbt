with raw_facilities as (
    -- the raw table, not the facilities base, so the partition is checked
    -- independently of the base's own filter
    select
        id,
        sensitive_network_id
    from {{ source('tamanu', 'facilities') }}
    where deleted_at is null
),

base as (
    select count(*) as total_referrals
    from {{ ref('referrals') }} r
    join {{ ref('encounters') }} e
        on e.id = r.initiating_encounter_id
    join {{ ref('locations') }} l
        on l.id = e.location_id
    join raw_facilities f
        on f.id = l.facility_id
    where f.sensitive_network_id is null
),

dataset as (
    select count(*) as total_referrals
    from {{ ref('ds__referrals') }}
)

select
    base.total_referrals as base_total_referrals,
    dataset.total_referrals as dataset_total_referrals
from base
join dataset on dataset.total_referrals != base.total_referrals
