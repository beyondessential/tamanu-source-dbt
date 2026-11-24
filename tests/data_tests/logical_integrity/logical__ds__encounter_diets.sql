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
    select count(*) as total_patients
    from {{ ref('encounters') }} e
    join {{ ref('locations') }} l
        on l.id = e.location_id
    join raw_facilities f
        on f.id = l.facility_id
        and f.sensitive_network_id is null
    where e.end_datetime is null
),

dataset as (
    select count(*) as total_patients
    from {{ ref('ds__encounter_diets') }}
)

select
    base.total_patients as base_total_patients,
    dataset.total_patients as dataset_total_patients
from base
join dataset on dataset.total_patients != base.total_patients
