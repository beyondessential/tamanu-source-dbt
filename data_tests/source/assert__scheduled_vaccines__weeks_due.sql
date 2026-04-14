select
    category,
    vaccine_id
from {{ source("tamanu", "scheduled_vaccines") }}
where weeks_from_birth_due notnull
    and index != 1
    and visibility_status = 'current'
group by
    category,
    vaccine_id

union

select
    category,
    vaccine_id
from {{ source("tamanu", "scheduled_vaccines") }}
where weeks_from_last_vaccination_due notnull
    and index = 1
    and visibility_status = 'current'
group by
    category,
    vaccine_id
