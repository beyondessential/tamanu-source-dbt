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
    select count(*) as total_procedures
    from {{ ref('procedures') }} p
    join {{ ref('encounters') }} e
        on e.id = p.encounter_id
    join {{ ref('locations') }} l
        on l.id = e.location_id
    join raw_facilities f
        on f.id = l.facility_id
    where f.sensitive_network_id is null
),

dataset as (
    select count(*) as total_procedures
    from {{ ref('ds__procedures') }}
)

select
    base.total_procedures as base_total_procedures,
    dataset.total_procedures as dataset_total_procedures
from base
join dataset on dataset.total_procedures != base.total_procedures
