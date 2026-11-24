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
    select count(*) as total_diagnoses
    from {{ ref('encounter_diagnoses') }} ed
    join {{ ref('encounters') }} e
        on e.id = ed.encounter_id
    join {{ ref('locations') }} l
        on l.id = e.location_id
    join raw_facilities f
        on f.id = l.facility_id
    where f.sensitive_network_id is null
),

dataset as (
    select count(*) as total_diagnoses
    from {{ ref('ds__diagnoses') }}
)

select
    base.total_diagnoses as base_total_diagnoses,
    dataset.total_diagnoses as dataset_total_diagnoses
from base
join dataset on dataset.total_diagnoses != base.total_diagnoses
