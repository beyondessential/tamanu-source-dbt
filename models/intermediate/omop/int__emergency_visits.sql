-- int__emergency_visits -- one row per emergency department attendance, carrying every
-- attribute the emergency care metrics disaggregate by.
--
-- Shared base for metric__emergency_visit and metric__emergency_stay. Both are
-- one-row-per-attendance over the same span, so the inclusion rule, the joins and the
-- derived timings live here once rather than in each metric.
--
-- Ephemeral, so this is inlined into each consumer and materialises nothing.
--
-- Specs: specs/dbt-model/metric__emergency_visit.md,
-- specs/dbt-model/metric__emergency_stay.md

with visit_detail as (
    select * from {{ ref('clinical__visit_detail') }}
),

visit_occurrence as (
    select * from {{ ref('clinical__visit_occurrence') }}
),

person as (
    select * from {{ ref('clinical__person') }}
),

locations as (
    select * from {{ ref('locations') }}
),

encounters as (
    select * from {{ ref('encounters') }}
),

triages as (
    select * from {{ ref('triages') }}
),

discharges as (
    select * from {{ ref('discharges') }}
),

reference_data as (
    select * from {{ ref('reference_data') }}
),

condition_occurrence as (
    select * from {{ ref('clinical__condition_occurrence') }}
),

-- BL-013: at most one principal diagnosis per encounter. Tamanu does not stop a second
-- is_primary row being recorded, so the earliest is taken (condition_occurrence_id breaks a
-- datetime tie) -- without this the join below would fan out and duplicate an attendance.
principal_diagnoses as (
    select
        visit_occurrence_id,
        condition_source_value,
        row_number() over (
            partition by visit_occurrence_id
            order by condition_start_datetime, condition_occurrence_id
        ) as diagnosis_rank
    from condition_occurrence
    where is_primary
),

-- BL-003: the ED intake segment of each encounter -- the first history segment whose OMOP
-- visit concept is 9203/Emergency Room Visit, covering emergency, triage and observation.
ed_intake as (
    select
        visit_occurrence_id,
        visit_detail_start_datetime,
        care_site_id
    from visit_detail
    where preceding_visit_detail_id is null
        and visit_detail_concept_id = 9203 -- OMOP 'Emergency Room Visit'
),

-- BL-018: the first time the patient's location leaves the ED. A segment boundary is not by
-- itself a departure: an encounter_type change to admission closes the intake segment while
-- the patient is still physically in the emergency department, which is the boarding case a
-- four-hour measure exists to expose. Only a change of care_site is a physical departure.
ed_location_exits as (
    select
        later.visit_occurrence_id,
        min(later.visit_detail_start_datetime) as ed_location_exit__datetime
    from visit_detail later
    join ed_intake i
        on i.visit_occurrence_id = later.visit_occurrence_id
    where later.visit_detail_start_datetime > i.visit_detail_start_datetime
        and later.care_site_id is distinct from i.care_site_id
    group by later.visit_occurrence_id
),

-- BL-003: one row per attendance, attributed to that intake segment.
attendances as (
    select
        -- BL-011: the encounter id is the subject. One intake segment per encounter, so this
        -- is unique across the rows emitted here.
        vd.visit_occurrence_id,
        vd.visit_detail_start_datetime as ed_start__datetime,
        -- BL-018: departure from the emergency department, taken as the earliest signal that
        -- the patient left: the first move to another location, or the time a booked transfer
        -- takes effect. least() ignores NULLs, so whichever exists wins and the earlier wins
        -- when both do. Falling through to the encounter end covers a discharge straight from
        -- the ED and any encounter that never moved.
        coalesce(
            least(x.ed_location_exit__datetime, enc.planned_location_start_datetime),
            vo.visit_end_datetime
        ) as ed_end__datetime,
        -- Encounter end is discharge from hospital, so for an admitted patient it is later
        -- than the ED departure. NULL = encounter still open.
        vo.visit_end_datetime as visit_end__datetime,
        loc.facility_id,
        pr.gender_source_value as sex,
        -- BL-005: visit-level concept 262 ('Emergency Room and Inpatient Visit') is the
        -- admitted episode-end status; it exists only at visit grain.
        coalesce(vo.visit_concept_id = 262, false) as is_admitted,
        -- BL-012: the triage practitioner's acuity category, '1' to '5'
        tr.score as triage_score_raw,
        -- BL-014: waiting time is triage to the start of active care, which is when the
        -- triage is closed. A time recorded before the triage is unusable.
        case
            when tr.closed_datetime < tr.triage_datetime then null
            else extract(epoch from (tr.closed_datetime - tr.triage_datetime))::bigint
        end as waiting_time__seconds,
        -- BL-015: time in the ED -- arrival to the departure resolved by BL-018. NULL only
        -- while the patient is in the ED and the encounter is still open.
        case
            when coalesce(
                    least(x.ed_location_exit__datetime, enc.planned_location_start_datetime),
                    vo.visit_end_datetime
                ) is null then null
            else extract(epoch from (
                    coalesce(
                        least(x.ed_location_exit__datetime, enc.planned_location_start_datetime),
                        vo.visit_end_datetime
                    ) - vd.visit_detail_start_datetime
                ))::bigint
        end as ed_time__seconds,
        -- BL-015: total length of stay -- arrival to discharge from hospital, so it spans the
        -- inpatient episode for an admitted patient. NULL while the encounter is open.
        case
            when vo.visit_end_datetime is null then null
            else extract(epoch from (
                    vo.visit_end_datetime - vd.visit_detail_start_datetime
                ))::bigint
        end as length_of_stay__seconds,
        -- BL-017: how the encounter ended. Encounter-grained, not ED-grained -- for an
        -- attendance that was admitted this is the eventual hospital discharge.
        disposition.name as discharge_disposition_raw,
        pdx.condition_source_value as principal_diagnosis_code,
        case
            when pr.year_of_birth is not null then
                extract(year from age(
                    vd.visit_detail_start_date,
                    make_date(pr.year_of_birth, pr.month_of_birth, pr.day_of_birth)
                ))::int
        end as age_years
    from visit_detail vd
    join person pr
        on pr.person_id = vd.person_id
    join visit_occurrence vo
        on vo.visit_occurrence_id = vd.visit_occurrence_id
    -- BL-007: facility is the intake segment's location. Inner join, so an encounter whose
    -- location does not resolve is excluded rather than attributed to a NULL facility.
    join locations loc
        on loc.id = vd.care_site_id
    -- BL-018: the booked transfer, one of the two departure signals. encounters.id is the
    -- primary key, so this yields one row per attendance.
    join encounters enc
        on enc.id = vd.visit_occurrence_id
    -- BL-018: the physical departure, where one has been recorded. Grouped to one row per
    -- encounter above, so it cannot fan out.
    left join ed_location_exits x
        on x.visit_occurrence_id = vd.visit_occurrence_id
    -- BL-012: left join -- an attendance with no triage record still counts. Tamanu records
    -- at most one triage per encounter, so this does not fan out; each metric's grain test is
    -- the backstop if that ever stops holding.
    left join triages tr
        on tr.encounter_id = vd.visit_occurrence_id
    -- BL-013: left join -- an attendance with no principal diagnosis still counts. Ranked to
    -- one row per encounter above, so this cannot fan out.
    left join principal_diagnoses pdx
        on pdx.visit_occurrence_id = vd.visit_occurrence_id
        and pdx.diagnosis_rank = 1
    -- BL-017: left join -- an attendance with no discharge record still counts. bases/discharges
    -- is `distinct on (encounter_id)`, so it holds one row per encounter and cannot fan out.
    left join discharges dis
        on dis.encounter_id = vd.visit_occurrence_id
    left join reference_data disposition
        on disposition.id = dis.disposition_id
    -- BL-010: no facilities.is_sensitive filter, so this covers standard and sensitive
    -- facilities alike.
    where vd.preceding_visit_detail_id is null
        and vd.visit_detail_concept_id = 9203 -- OMOP 'Emergency Room Visit'
)

select
    visit_occurrence_id,
    ed_start__datetime,
    ed_end__datetime,
    visit_end__datetime,
    facility_id,
    sex,
    age_years,
    is_admitted,
    waiting_time__seconds,
    -- BL-014: the wait as minutes, to two decimal places -- 0.6-second resolution, finer
    -- than any reporting need, and a fixed scale so the value is stable to compare. Minutes
    -- from whole seconds is a repeating decimal, so some scale has to be chosen.
    -- NULL until the patient reaches active care.
    round(waiting_time__seconds / 60.0, 2) as waiting_time__minutes,
    ed_time__seconds,
    -- BL-015: time in the ED as minutes, to two decimal places, on the same basis as
    -- waiting_time__minutes. NULL only while the patient is in the ED with nothing booked.
    round(ed_time__seconds / 60.0, 2) as ed_time__minutes,
    length_of_stay__seconds,
    -- BL-015: total length of stay as minutes, on the same basis as the other durations
    round(length_of_stay__seconds / 60.0, 2) as length_of_stay__minutes,
    principal_diagnosis_code,
    -- BL-012: 'Not recorded' covers both an attendance with no triage row and a triage row
    -- with a blank score. Never NULL -- the data tables expose these as array filters, and
    -- Tupaia's array filter drops NULL rows.
    coalesce(triage_score_raw, 'Not recorded') as triage_score,
    -- BL-017
    coalesce(discharge_disposition_raw, 'Not recorded') as discharge_disposition,
    -- BL-016: hour of the day the patient arrived, 0-23. Tamanu stores naive timestamps in
    -- the deployment's central timezone (var('timezone'), see to_user_selected_timezone), so
    -- this is already a local hour and needs no conversion. A deployment spanning timezones
    -- gets the central zone's hour, not each facility's.
    extract(hour from ed_start__datetime)::int as ed_start__hour
-- BL-019: no banding here. A four-hour split and an age classification are both presentation
-- choices a deployment may set differently, so the metrics emit the continuous value and the
-- consumer's data table bands it.
from attendances
