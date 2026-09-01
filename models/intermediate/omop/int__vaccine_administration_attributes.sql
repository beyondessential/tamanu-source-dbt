-- int__vaccine_administration_attributes -- one row per bases/vaccine_administrations row,
-- any status, carrying every attribute both immunisation metrics disaggregate by: facility,
-- antigen, schedule dose position, sex, EPI age-cohort input, and patient village. Also
-- resolves the not-given reason, populated only for a NOT_GIVEN row.
--
-- Shared base for metric__immunisation_dose (status = 'GIVEN') and
-- metric__immunisation_refusal (status = 'NOT_GIVEN'). Each reads its own identity and date
-- from its canonical OMOP-lite fact -- clinical__drug_exposure and clinical__observation
-- respectively -- and joins back here on id, rather than re-deriving these same joins twice.
--
-- None of these fields (disease, dose position, not-given reason) has an OMOP DRUG_EXPOSURE
-- or OBSERVATION equivalent, so they are resolved here, off bases/vaccine_administrations
-- directly, rather than bolted onto either canonical fact.
--
-- Ephemeral, so this is inlined into each consumer and materialises nothing.
--
-- Specs: specs/dbt-model/metric__immunisation_dose.md, specs/dbt-model/metric__immunisation_refusal.md

with vaccine_administrations as (
    select * from {{ ref('vaccine_administrations') }}
),

vaccine_schedules as (
    select * from {{ ref('vaccine_schedules') }}
),

locations as (
    select * from {{ ref('locations') }}
),

person as (
    select * from {{ ref('clinical__person') }}
),

encounters as (
    select * from {{ ref('encounters') }}
),

reference_data as (
    select * from {{ ref('reference_data') }}
)

select
    av.id as administered_vaccine_id,
    -- facility comes from the event's own recorded location, not resolved via the encounter's
    -- segment -- a vaccination (or an attempt) can be given in a different room/location than
    -- where the encounter's other activity was recorded. Inner join: a row recorded as given
    -- elsewhere carries no location_id and is excluded rather than attributed to a NULL
    -- facility, since it was not administered at one of this deployment's own facilities --
    -- same convention every other metric__ model uses for a row whose location fails to
    -- resolve.
    loc.facility_id,
    -- the antigen the event addresses -- no OMOP equivalent, read directly.
    av.disease,
    -- the schedule's dose position (e.g. 'Dose 1', or a due-time label like 'Birth'). Left
    -- join -- an ad hoc/catch-up dose carries no scheduled_vaccine_id at all and is still a
    -- legitimate row, not excluded.
    vs.dose_label,
    pr.gender_source_value as sex,
    -- the patient's own residence, distinct from facility_id (where the event happened).
    pr.location_id as patient_location_id,
    -- reason a dose was not given -- reference_data's name for the coded reason, falling back
    -- to the free-text reason. NULL for a GIVEN row: only a NOT_GIVEN row carries this.
    case
        when av.status = 'NOT_GIVEN' then coalesce(rdr.name, av.reason)
    end as not_given_reason,
    -- age in whole months at the event date -- null year_of_birth -> null age.
    -- month_of_birth/day_of_birth are extracted from the same date_of_birth column in
    -- clinical__person, so they're populated whenever year_of_birth is -- make_date never
    -- errors on a partial date.
    case
        when pr.year_of_birth is not null then
            (extract(year from age(
                av.datetime::date,
                make_date(pr.year_of_birth, pr.month_of_birth, pr.day_of_birth)
            )) * 12 + extract(month from age(
                av.datetime::date,
                make_date(pr.year_of_birth, pr.month_of_birth, pr.day_of_birth)
            )))::int
    end as age_months
from vaccine_administrations av
join encounters e
    on e.id = av.encounter_id
join locations loc
    on loc.id = av.location_id
left join vaccine_schedules vs
    on vs.id = av.scheduled_vaccine_id
left join reference_data rdr
    on rdr.id = av.not_given_reason_id
-- inner join: a row whose patient bases/patients excludes (soft-deleted or merged away) is
-- excluded rather than carried with blank demographics -- same convention every other
-- metric__ model uses.
join person pr
    on pr.person_id = e.patient_id
