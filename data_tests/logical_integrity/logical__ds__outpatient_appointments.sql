with base as (
    select count(*) as total_appointments
    from {{ ref('outpatient_appointments') }} lb
    join {{ ref('location_groups') }} lg
        on lg.id = lb.location_group_id
    join {{ ref('facilities') }} f
        on f.id = lg.facility_id
    where not f.is_sensitive
),

dataset as (
    select count(*) as total_appointments
    from {{ ref('ds__outpatient_appointments') }}
)

select
    base.total_appointments as base_total_appointments,
    dataset.total_appointments as dataset_total_appointments
from base
join dataset on dataset.total_appointments != base.total_appointments
