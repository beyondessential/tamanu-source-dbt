select
    eh.id,
    eh.encounter_id,
    eh.datetime as start_datetime,
    eh.encounter_type
from {{ ref('encounter_history') }} eh
where (eh.change_type isnull or eh.change_type = 'encounter_type')
window w as (
    partition by eh.encounter_id
    order by eh.datetime
)
