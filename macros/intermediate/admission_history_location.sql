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
),

-- BL-014 (specs/reports/hospital-admissions-summaries.md): consecutive rows that did not
-- move the patient are one episode. A row qualifies for the log above when it changes the
-- encounter type as well as when it changes the location, so an encounter converted to an
-- admission without being moved opened a second episode in the same location -- which then
-- read as a transfer out of a location the patient never left.
numbered as (
    select
        ll.id,
        ll.encounter_id,
        ll.location_id,
        ll.start_datetime,
        ll.type,
        {{ contiguous_phase_id('ll.encounter_id', ['ll.location_id'], 'll.start_datetime, ll.id') }} as phase_id
    from admission_location_log ll
),

-- the episode starts when the patient arrived and carries every event that happened
-- while they were there. Both flags survive the merge rather than the opening row's type
-- alone: a patient transferred in and then converted to an admission without moving did
-- both, in this location, and keeping only the first row's type would discard the admission.
location_phases as (
    select
        encounter_id,
        location_id,
        min(start_datetime) as start_datetime,
        bool_or(type = 'admission')   as is_admission,
        bool_or(type = 'transfer-in') as is_transfer_in
    from numbered
    group by encounter_id, location_id, phase_id
)

select
    ll.encounter_id,
    -- BL-013: the area is resolved through the location_groups row, not through the
    -- foreign key on locations. A soft-deleted group leaves the key populated while the
    -- row is gone; taking the id from here makes that behave as no group at all, so it
    -- lands in the same bucket as a location that never had one.
    lg.id as location_group_id,
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
    coalesce(ll.is_admission, false) as admission,
    coalesce(lead(ll.location_id) over w isnull and e.end_datetime notnull, false) as discharge,
    coalesce(ll.is_transfer_in, false) as transfer_in,
    coalesce(lead(ll.location_id) over w notnull, false) as transfer_out,
    -- BL-004 (specs/reports/hospital-admissions-summaries.md): the death is attributed
    -- to the final episode, and the patient must have died *during* the encounter.
    -- `date_of_death` is a timestamp, so comparing it to `end_datetime::date` promoted
    -- the date to midnight and could only match a death recorded at exactly 00:00:00.
    -- Interval containment is the idiom ds__deaths already uses for the same question.
    coalesce(
        lead(ll.start_datetime) over w isnull
            and p.date_of_death between e.start_datetime and e.end_datetime,
        false
    ) as death
from location_phases ll
join {{ ref('encounters') }} e on e.id = ll.encounter_id
join {{ ref('patients') }} p on p.id = e.patient_id
join {{ ref('locations') }} l on l.id = ll.location_id
-- BL-013 (specs/reports/hospital-admissions-summaries.md): left join. A location
-- with no location_group is real and its episodes count; an inner join here dropped
-- them from -by-area and -by-location entirely, deaths included.
left join {{ ref('location_groups') }} lg on lg.id = l.location_group_id
-- BL-012 (specs/reports/hospital-admissions-summaries.md): facility partition
join {{ ref('facilities') }} f
    on f.id = l.facility_id
    and coalesce(f.is_sensitive, false) = {{ is_sensitive }}
window w as (
    partition by ll.encounter_id
    order by ll.start_datetime
)

{% endmacro %}
