select
    av.id,
    av.date::timestamp as datetime,
    av.encounter_id,
    av.location_id,
    av.department_id,
    av.scheduled_vaccine_id,
    av.status,
    av.reason,
    av.not_given_reason_id,
    av.batch,
    av.vaccine_name,
    av.vaccine_brand,
    av.disease,
    av.consent as is_consented,
    av.consent_given_by,
    av.injection_site,
    av.given_by,
    av.given_elsewhere as is_given_elsewhere,
    av.circumstance_ids,
    av.recorder_id as recorded_by_id,
    av.updated_at::timestamp as last_modified_at
from {{ source("tamanu", "administered_vaccines") }} av
join {{ source("tamanu", "encounters") }} e on e.id = av.encounter_id
where av.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
