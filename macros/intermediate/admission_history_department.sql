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
),

-- BL-014 (specs/reports/hospital-admissions-summaries.md): consecutive rows that did not
-- move the patient are one episode. A row qualifies for the log above when it changes the
-- encounter type as well as when it changes the department, so an encounter converted to an
-- admission without being moved opened a second episode in the same department -- which then
-- read as a transfer out of a department the patient never left.
numbered as (
    select
        dl.id,
        dl.encounter_id,
        dl.department_id,
        dl.start_datetime,
        dl.type,
        {{ contiguous_phase_id('dl.encounter_id', ['dl.department_id'], 'dl.start_datetime, dl.id') }} as phase_id
    from admission_department_log dl
),

-- the episode starts when the patient arrived and carries every event that happened
-- while they were there. The two flags are NOT aggregated the same way, because the two
-- events are not the same shape. A patient is moved into a department once, at the moment the
-- episode opens, so `transfer_in` is the opening row's type. Conversion to an admission can
-- happen at any point during the stay, so `admission` is true if any row in the run carried
-- one: a patient transferred in and later converted without moving did both, and keeping
-- only the opening row's type would discard the admission.
--
-- Aggregating `transfer_in` the same way would invent transfers. A history row that sets
-- `department` to the one already held is typed `transfer-in` by the log above but moved
-- nobody; absorbed into an encounter's FIRST episode it reads as a transfer into a department
-- the patient arrived in directly, with no transfer out anywhere to match it.
department_phases as (
    select
        encounter_id,
        department_id,
        min(start_datetime) as start_datetime,
        bool_or(type = 'admission') as is_admission,
        (array_agg(type order by start_datetime, id))[1] = 'transfer-in' as is_transfer_in
    from numbered
    group by encounter_id, department_id, phase_id
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
    coalesce(dl.is_admission, false) as admission,
    coalesce(lead(dl.department_id) over w isnull and e.end_datetime notnull, false) as discharge,
    coalesce(dl.is_transfer_in, false) as transfer_in,
    coalesce(lead(dl.department_id) over w notnull, false) as transfer_out,
    -- BL-004 (specs/reports/hospital-admissions-summaries.md): the death is attributed
    -- to the final episode, and the patient must have died *during* the encounter.
    -- `date_of_death` is a timestamp, so comparing it to `end_datetime::date` promoted
    -- the date to midnight and could only match a death recorded at exactly 00:00:00.
    -- Interval containment is the idiom ds__deaths already uses for the same question.
    coalesce(
        lead(dl.start_datetime) over w isnull
            and p.date_of_death between e.start_datetime and e.end_datetime,
        false
    ) as death
from department_phases dl
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
