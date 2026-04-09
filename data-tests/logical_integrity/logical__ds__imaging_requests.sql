with base as (
    select count(*) as total_requests
    from {{ ref('imaging_requests') }} ir
    join {{ ref('encounters') }} e
        on e.id = ir.encounter_id
    join {{ ref('locations') }} l
        on l.id = e.location_id
    join {{ ref('facilities') }} f
        on f.id = l.facility_id
    where not f.is_sensitive
),
dataset as (
    select count(*) as total_requests
    from {{ ref('ds__imaging_requests') }}
)
select base.total_requests as base_total_requests,
       dataset.total_requests as dataset_total_requests
from base
join dataset on dataset.total_requests != base.total_requests