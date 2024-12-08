select
    ltpr.id,
    ltpr.lab_test_panel_id,
    ltpr.encounter_id
from {{ source("tamanu", "lab_test_panel_requests") }} ltpr
join {{ source("tamanu", "encounters") }} e on e.id = ltpr.encounter_id
where ltpr.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
