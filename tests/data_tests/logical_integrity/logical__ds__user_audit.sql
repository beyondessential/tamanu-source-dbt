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
    select count(*) as total_encounters
    from {{ ref('encounters') }} e
    join {{ ref('locations') }} l
        on l.id = e.location_id
    join raw_facilities f
        on f.id = l.facility_id
    where f.sensitive_network_id is null
),

dataset as (
    select count(*) as total_encounters
    from {{ ref('ds__user_audit') }}
)

select
    base.total_encounters as base_total_encounters,
    dataset.total_encounters as dataset_total_encounters
from base
join dataset on dataset.total_encounters != base.total_encounters
