select
    id,
    name,
    type,
    created_at at time zone '{{ var("timezone") }}' as created_datetime,
    patient_id,
    encounter_id
from {{ source('tamanu', 'document_metadata') }}
where deleted_at is null

