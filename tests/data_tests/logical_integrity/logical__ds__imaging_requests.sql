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
    select count(*) as total_requests
    from {{ ref('imaging_requests') }} ir
    join {{ ref('encounters') }} e
        on e.id = ir.encounter_id
    join {{ ref('locations') }} l
        on l.id = e.location_id
    join raw_facilities f
        on f.id = l.facility_id
    where f.sensitive_network_id is null
),

dataset as (
    select count(*) as total_requests
    from {{ ref('ds__imaging_requests') }}
)

select
    base.total_requests as base_total_requests,
    dataset.total_requests as dataset_total_requests
from base
join dataset on dataset.total_requests != base.total_requests
