select
    eh.id,
    eh.encounter_id,
    eh.datetime as start_datetime,
    eh.clinician_id
from {{ ref('encounter_history') }} eh
where (eh.change_type isnull or eh.change_type = 'examiner')
window w as (
    partition by eh.encounter_id
    order by eh.datetime
)
