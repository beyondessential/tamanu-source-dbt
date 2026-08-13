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

-- BL-003: ED attendances are the first history segment of each encounter whose OMOP visit
-- concept is 9203/Emergency Room Visit -- covers emergency, triage and observation. One row
-- per attendance, attributed to that intake segment.
attendances as (
    select
        -- BL-011: the encounter id is the subject. One intake segment per encounter, so this
        -- is unique across the rows emitted here.
        vd.visit_occurrence_id,
        vd.visit_detail_start_datetime as ed_start__datetime,
        -- BL-002: two distinct departures, and the metrics use different ones.
        -- ED departure is when the patient leaves the emergency department: the intake
        -- segment's end, which is an internal transfer to an inpatient bed or a discharge
        -- straight from the ED.
        -- BL-018: where the segment has no end, a planned location stands in for it -- the
        -- encounter is booked to transfer out of the ED at planned_location_start_datetime, so
        -- the ED episode is settled even though the next segment is unrecorded. An actual
        -- segment end always wins over the plan. NULL = in the ED with no transfer planned.
        -- encounters holds CURRENT state, so this reads a live plan only; a transfer that has
        -- already happened closed the segment and is read from there instead. No historical
        -- planned-location change is recoverable here -- encounter_history omits the field, so
        -- it lives only in logs.changes. See OQ-002 in the metric__emergency_stay spec.
        coalesce(
            vd.visit_detail_end_datetime, enc.planned_location_start_datetime
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
        -- BL-015: time in the ED -- arrival to ED departure, including a departure supplied by
        -- a planned location (BL-018). NULL while the patient is in the ED with no transfer
        -- planned.
        case
            when coalesce(vd.visit_detail_end_datetime, enc.planned_location_start_datetime) is null
                then null
            else extract(epoch from (
                    coalesce(vd.visit_detail_end_datetime, enc.planned_location_start_datetime)
                    - vd.visit_detail_start_datetime
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
    -- BL-018: planned location, for the ED departure fallback. encounters.id is the primary
    -- key, so this yields one row per attendance.
    join encounters enc
        on enc.id = vd.visit_occurrence_id
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
    -- waiting_time__minutes. NULL while the patient is in the ED with no transfer planned.
    round(ed_time__seconds / 60.0, 2) as ed_time__minutes,
    length_of_stay__seconds,
    principal_diagnosis_code,
    -- BL-012: 'Not recorded' covers both an attendance with no triage row and a triage row
    -- with a blank score. Never NULL -- these are data table filter columns downstream, and
    -- Tupaia's array filter drops NULL rows.
    coalesce(triage_score_raw, 'Not recorded') as triage_score,
    -- BL-017
    coalesce(discharge_disposition_raw, 'Not recorded') as discharge_disposition,
    -- BL-016: hour of the day the patient arrived, 0-23. Tamanu stores naive timestamps in
    -- the deployment's central timezone (var('timezone'), see to_user_selected_timezone), so
    -- this is already a local hour and needs no conversion. A deployment spanning timezones
    -- gets the central zone's hour, not each facility's.
    extract(hour from ed_start__datetime)::int as ed_start__hour,
    -- BL-015: the four-hour threshold, applied to each duration. Two separate columns because
    -- the two measure different things and are not comparable -- metric__emergency_stay uses
    -- time in the ED, metric__emergency_visit uses total length of stay.
    case
        when ed_time__seconds is null then 'Unknown'
        when ed_time__seconds < 4 * 60 * 60 then '< 4 hours'
        else '4 or more hours'
    end as ed_time__4_hours_band,
    case
        when length_of_stay__seconds is null then 'Unknown'
        when length_of_stay__seconds < 4 * 60 * 60 then '< 4 hours'
        else '4 or more hours'
    end as length_of_stay__4_hours_band
from attendances
