select
    eh.id,
    eh.encounter_id,
    e.patient_id,
    eh.datetime as start_datetime,
    e.end_datetime,
    eh.department_id,
    eh.location_id,
    l.location_group_id,
    eh.clinician_id
from {{ ref('encounter_history') }} eh
join {{ ref('encounters') }} e on e.id = eh.encounter_id
join {{ ref('locations') }} l on l.id = eh.location_id
where eh.encounter_type = 'admission'
    and (eh.change_type isnull or eh.change_type = 'encounter_type')
