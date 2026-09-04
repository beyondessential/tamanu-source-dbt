{% macro admission_history_location(is_sensitive=false) %}

{#-
    Admission episodes per location, partitioned by facility sensitivity.

    See specs/reports/hospital-admissions-summaries.md for the BL clauses.

    BL-012: the facility scope is partitioned by is_sensitive, exhaustively and
    disjointly, so each facility's episodes reach exactly one of the two variants. The
    join to facilities exists only to resolve the facility name; the predicate is what
    makes it a partition.

    The coalesce is what makes it exhaustive. facilities.is_sensitive carries no not_null
    test, and a bare `= true` / `= false` pair matches neither variant for a null, which
    would drop that facility from all six reports rather than move it. A null reads as
    non-sensitive, which is where such a facility's episodes appeared before the partition
    existed.
-#}

with admission_location_log as (
    select
        eh.id,
        eh.encounter_id,
        eh.datetime as start_datetime,
        eh.location_id,
        case
            when eh.change_type is null or 'encounter_type' = any(eh.change_type) then 'admission'
            else 'transfer-in'
        end as type
    from {{ ref('encounter_history') }} eh
    where (eh.change_type isnull or eh.change_type && array['location', 'encounter_type'])
        and eh.encounter_type = 'admission'
)

select
    ll.encounter_id,
    l.location_group_id,
    lg.name as location_group,
    ll.location_id,
    l.name as location,
    l.facility_id,
    f.name as facility,
    ll.start_datetime,
    coalesce(lead(ll.start_datetime) over w, e.end_datetime) as end_datetime,
    case
        when coalesce(lead(ll.start_datetime::date) over w, e.end_datetime::date) - ll.start_datetime::date < 1 then 1
        else coalesce(lead(ll.start_datetime::date) over w, e.end_datetime::date) - ll.start_datetime::date
    end as length_of_stay,
    coalesce(ll.type = 'admission', false) as admission,
    coalesce(lead(ll.location_id) over w isnull and e.end_datetime notnull, false) as discharge,
    coalesce(ll.type = 'transfer-in', false) as transfer_in,
    coalesce(lead(ll.location_id) over w notnull, false) as transfer_out,
    coalesce(lead(ll.start_datetime) over w isnull and e.end_datetime::date = p.date_of_death, false) as death
from admission_location_log ll
join {{ ref('encounters') }} e on e.id = ll.encounter_id
join {{ ref('patients') }} p on p.id = e.patient_id
join {{ ref('locations') }} l on l.id = ll.location_id
join {{ ref('location_groups') }} lg on lg.id = l.location_group_id
-- BL-012 (specs/reports/hospital-admissions-summaries.md): facility partition
join {{ ref('facilities') }} f
    on f.id = l.facility_id
    and coalesce(f.is_sensitive, false) = {{ is_sensitive }}
window w as (
    partition by ll.encounter_id
    order by ll.start_datetime
)

{% endmacro %}
