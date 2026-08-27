-- int__inpatient_admission -- one row per inpatient admission, carrying every attribute
-- metric__inpatient_admission disaggregates by.
--
-- Shared base for metric__inpatient_admission and any inpatient metric added later.
--
-- Ephemeral, so this is inlined into each consumer and materialises nothing.
--
-- Spec: specs/dbt-model/metric__inpatient_admission.md

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
-- datetime tie) -- without this the join below would fan out and duplicate an admission.
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

-- BL-003: the admission segment of each encounter -- the earliest history segment whose OMOP
-- visit concept is 9201/Inpatient Visit. For a direct admission this is also the encounter's
-- first segment; for an encounter that passed through an ED/triage/observation phase first
-- (visit-level concept 262) it is the later segment where the patient actually became an
-- inpatient -- anchoring on the first segment unconditionally, as int__emergency_visits does
-- for 9203, would miss every ED-then-admitted encounter.
admission_segments as (
    select
        visit_occurrence_id,
        person_id,
        visit_detail_start_datetime as admission_start__datetime,
        care_site_id,
        department_id,
        row_number() over (
            partition by visit_occurrence_id
            order by visit_detail_start_datetime, visit_detail_id
        ) as admission_rank
    from visit_detail
    where visit_detail_concept_id = 9201 -- OMOP 'Inpatient Visit'
),

-- BL-003: one row per admission, attributed to that admission segment. An encounter with no
-- segment at concept 9201 at all -- a pure ED or outpatient encounter -- has no row here.
admissions as (
    select
        -- BL-011: the encounter id is the subject. One admission segment per encounter, so
        -- this is unique across the rows emitted here.
        adm.visit_occurrence_id,
        adm.admission_start__datetime,
        -- Encounter end is discharge from hospital. NULL = encounter still open.
        vo.visit_end_datetime as visit_end__datetime,
        loc.facility_id,
        -- BL-007: the ward is the admission segment's department, carried as the Tamanu id
        -- only -- resolving it to a name is a consumer-layer concern, same convention as
        -- facility_id (BL-009). Nullable: an admission segment recorded with no department
        -- stays NULL rather than being excluded.
        adm.department_id as admission_ward_id,
        pr.gender_source_value as sex,
        -- BL-005: visit-level concept 262 ('Emergency Room and Inpatient Visit') marks an
        -- admission that had a prior ED/triage/observation phase; it exists only at visit
        -- grain.
        coalesce(vo.visit_concept_id = 262, false) as is_admitted_via_emergency,
        -- BL-012: how the patient arrived, from the encounter's referral source.
        admission_source_ref.name as admission_source_raw,
        -- BL-014: how the encounter ended.
        disposition.name as discharge_disposition_raw,
        pdx.condition_source_value as principal_diagnosis_code,
        case
            when pr.year_of_birth is not null then
                extract(year from age(
                    adm.admission_start__datetime::date,
                    make_date(pr.year_of_birth, pr.month_of_birth, pr.day_of_birth)
                ))::int
        end as age_years,
        -- BL-015: total time as an inpatient -- admission to discharge from hospital. NULL
        -- while the encounter is open.
        case
            when vo.visit_end_datetime is null then null
            else extract(epoch from (
                    vo.visit_end_datetime - adm.admission_start__datetime
                ))::bigint
        end as length_of_stay__seconds
    from admission_segments adm
    join person pr
        on pr.person_id = adm.person_id
    join visit_occurrence vo
        on vo.visit_occurrence_id = adm.visit_occurrence_id
    -- BL-007: facility is the admission segment's location. Inner join, so an admission whose
    -- location does not resolve is excluded rather than attributed to a NULL facility.
    join locations loc
        on loc.id = adm.care_site_id
    -- BL-012: the referral source lives on the encounter, not on clinical__visit_occurrence.
    join encounters enc
        on enc.id = adm.visit_occurrence_id
    -- BL-012: left join -- an admission with no referral source still counts.
    left join reference_data admission_source_ref
        on admission_source_ref.id = enc.referral_source_id
    -- BL-014: left join -- an admission with no discharge record still counts. bases/discharges
    -- is `distinct on (encounter_id)`, so it holds one row per encounter and cannot fan out.
    left join discharges dis
        on dis.encounter_id = adm.visit_occurrence_id
    left join reference_data disposition
        on disposition.id = dis.disposition_id
    -- BL-013: left join -- an admission with no principal diagnosis still counts. Ranked to
    -- one row per encounter above, so this cannot fan out.
    left join principal_diagnoses pdx
        on pdx.visit_occurrence_id = adm.visit_occurrence_id
        and pdx.diagnosis_rank = 1
    -- BL-010: no facilities.is_sensitive filter, so this covers standard and sensitive
    -- facilities alike.
    where adm.admission_rank = 1
)

select
    visit_occurrence_id,
    admission_start__datetime,
    visit_end__datetime,
    facility_id,
    admission_ward_id,
    sex,
    age_years,
    is_admitted_via_emergency,
    -- BL-012: 'Not recorded' covers an admission with no referral source. Never NULL -- the
    -- data tables expose this as an array filter, and Tupaia's array filter drops NULL rows.
    coalesce(admission_source_raw, 'Not recorded') as admission_source,
    length_of_stay__seconds,
    -- BL-015: length of stay as minutes, to two decimal places -- 0.6-second resolution, finer
    -- than any reporting need, and a fixed scale so the value is stable to compare.
    round(length_of_stay__seconds / 60.0, 2) as length_of_stay__minutes,
    principal_diagnosis_code,
    -- BL-014: 'Not recorded' covers an admission with no discharge record. Never NULL, for the
    -- same reason as admission_source.
    coalesce(discharge_disposition_raw, 'Not recorded') as discharge_disposition
from admissions
