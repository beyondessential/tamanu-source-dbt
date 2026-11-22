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
    select count(*) as total_bookings
    from {{ ref('location_bookings') }} lb
    join {{ ref('locations') }} l
        on l.id = lb.location_id
    join raw_facilities f
        on f.id = l.facility_id
    where f.sensitive_network_id is null
),

dataset as (
    select count(*) as total_bookings
    from {{ ref('ds__location_bookings') }}
)

select
    base.total_bookings as base_total_bookings,
    dataset.total_bookings as dataset_total_bookings
from base
join dataset on dataset.total_bookings != base.total_bookings
