select
    id,
    created_at at time zone '{{ var("timezone") }}' as created_datetime,
    updated_at at time zone '{{ var("timezone") }}' as updated_datetime,
    display_id,
    first_name,
    middle_name,
    last_name,
    cultural_name,
    email,
    initcap(sex::text) as sex,
    date_of_birth::date as date_of_birth,
    date_of_death::timestamp as date_of_death,
    village_id
from {{ source('tamanu', 'patients') }}
where deleted_at is null
    and id != '{{ var("test_patient") }}'
    and visibility_status != 'merged'
