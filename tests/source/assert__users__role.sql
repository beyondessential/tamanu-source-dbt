select u.role
from {{ source("tamanu", "users") }} u
left join {{ source("tamanu", "roles") }} r on r.id = u.role
where r.id is null
    and u.role not in ('admin', 'practitioner')
