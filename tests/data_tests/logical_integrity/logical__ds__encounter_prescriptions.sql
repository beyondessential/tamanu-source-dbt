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
    select count(*) as total_prescriptions
    from {{ ref('encounter_prescriptions') }} ep
    join {{ ref('encounters') }} e
        on e.id = ep.encounter_id
    join {{ ref('locations') }} l
        on l.id = e.location_id
    join raw_facilities f
        on f.id = l.facility_id
    where f.sensitive_network_id is null
),

dataset as (
    select count(*) as total_prescriptions
    from {{ ref('ds__encounter_prescriptions') }}
)

select
    base.total_prescriptions as base_total_prescriptions,
    dataset.total_prescriptions as dataset_total_prescriptions
from base
join dataset on dataset.total_prescriptions != base.total_prescriptions
