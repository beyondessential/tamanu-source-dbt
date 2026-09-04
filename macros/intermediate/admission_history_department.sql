{% macro admission_history_department(is_sensitive=false) %}

{#-
    Admission episodes per department, partitioned by facility sensitivity.

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

with admission_department_log as (
    select
        eh.id,
        eh.encounter_id,
        eh.datetime as start_datetime,
        eh.department_id,
        case
            when eh.change_type is null or 'encounter_type' = any(eh.change_type) then 'admission'
            else 'transfer-in'
        end as type
    from {{ ref('encounter_history') }} eh
    where (eh.change_type isnull or eh.change_type && array['department', 'encounter_type'])
        and eh.encounter_type = 'admission'
)

select
    dl.encounter_id,
    dl.department_id,
    d.name as department,
    d.facility_id,
    f.name as facility,
    dl.start_datetime,
    coalesce(lead(dl.start_datetime) over w, e.end_datetime) as end_datetime,
    case
        when coalesce(lead(dl.start_datetime::date) over w, e.end_datetime::date) - dl.start_datetime::date < 1 then 1
        else coalesce(lead(dl.start_datetime::date) over w, e.end_datetime::date) - dl.start_datetime::date
    end as length_of_stay,
    coalesce(dl.type = 'admission', false) as admission,
    coalesce(lead(dl.department_id) over w isnull and e.end_datetime notnull, false) as discharge,
    coalesce(dl.type = 'transfer-in', false) as transfer_in,
    coalesce(lead(dl.department_id) over w notnull, false) as transfer_out,
    coalesce(lead(dl.start_datetime) over w isnull and e.end_datetime::date = p.date_of_death, false) as death
from admission_department_log dl
join {{ ref('encounters') }} e on e.id = dl.encounter_id
join {{ ref('patients') }} p on p.id = e.patient_id
join {{ ref('departments') }} d on d.id = dl.department_id
-- BL-012 (specs/reports/hospital-admissions-summaries.md): facility partition
join {{ ref('facilities') }} f
    on f.id = d.facility_id
    and coalesce(f.is_sensitive, false) = {{ is_sensitive }}
window w as (
    partition by encounter_id
    order by dl.start_datetime
)

{% endmacro %}
