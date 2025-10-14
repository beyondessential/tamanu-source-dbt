with base as (
    select count(*) as total_bookings
    from {{ ref('location_bookings') }} lb
    join {{ ref('locations') }} l
        on l.id = lb.location_id
    join {{ ref('facilities') }} f
        on f.id = l.facility_id
    where not f.is_sensitive
),
dataset as (
    select count(*) as total_bookings
    from {{ ref('ds__location_bookings') }}
)
select base.total_bookings as base_total_bookings,
       dataset.total_bookings as dataset_total_bookings
from base
join dataset on dataset.total_bookings != base.total_bookings