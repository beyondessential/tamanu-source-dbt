select
    eh.id,
    eh.encounter_id,
    eh.datetime as start_datetime,
    eh.location_id,
    l.location_group_id
from {{ ref('encounter_history') }} eh
join {{ ref('locations') }} l on l.id = eh.location_id
where (eh.change_type isnull or eh.change_type = 'location')
