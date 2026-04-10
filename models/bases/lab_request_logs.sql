select
    lrl.id,
    lrl.created_at at time zone '{{ var("timezone") }}' as created_datetime,
    lrl.updated_at at time zone '{{ var("timezone") }}' as updated_datetime,
    lrl.lab_request_id,
    lrl.status,
    lrl.updated_by_id
from {{ source('tamanu', 'lab_request_logs') }} lrl
join {{ source('tamanu', 'lab_requests') }} lr on lr.id = lrl.lab_request_id
join {{ source('tamanu', 'encounters') }} e on e.id = lr.encounter_id
where lrl.deleted_at is null
    and lr.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
