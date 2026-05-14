with base as (
    select count(*) as total_procedures
    from {{ ref('procedures') }} p
    join {{ ref('encounters') }} e
        on e.id = p.encounter_id
    join {{ ref('locations') }} l
        on l.id = e.location_id
    join {{ ref('facilities') }} f
        on f.id = l.facility_id
    where not f.is_sensitive
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
