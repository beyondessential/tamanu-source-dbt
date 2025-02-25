select
    id,
    display_id,
    first_name,
    middle_name,
    last_name,
    cultural_name,
    email,
    initcap(sex::text) as sex,
    date_of_birth::date,
    date_of_death::date,
    village_id,
    created_at::date as registration_date
from {{ source("tamanu", "patients") }}
where deleted_at is null
    and id != '{{ var("test_patient") }}'
    and visibility_status != 'merged'
