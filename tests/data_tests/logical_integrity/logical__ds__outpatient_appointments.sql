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
    select count(*) as total_appointments
    from {{ ref('outpatient_appointments') }} lb
    join {{ ref('location_groups') }} lg
        on lg.id = lb.location_group_id
    join raw_facilities f
        on f.id = lg.facility_id
    where f.sensitive_network_id is null
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
