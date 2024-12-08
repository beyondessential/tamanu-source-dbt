select
    ed.id,
    ed.encounter_id,
    ed.diet_id
from {{ source("tamanu", "encounter_diets") }} ed
join {{ source("tamanu", "encounters") }} e on e.id = ed.encounter_id
where ed.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
