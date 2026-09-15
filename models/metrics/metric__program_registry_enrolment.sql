-- metric__program_registry_enrolment -- D5 metric view for the program registry enrolment
-- indicator registered in documentations/metrics/*.yml: program_registry_enrolment.
-- Spec: specs/dbt-model/metric__program_registry_enrolment.md (BL-001..BL-013).
--
-- Per-enrolment (subject) grain: one row per patient enrolment in a program registry,
-- value_numeric 1, so a consumer aggregates at whatever grain it needs (BL-003).
--
-- period_start/period_end are the episode boundaries, so an enrolment open on a given day is
-- one whose period_start has passed and whose period_end is null or later (BL-002). Every
-- registry is emitted, keyed by registry_code, so one data table serves HIV, TB, NCD and
-- whatever else a deployment configures (BL-004).
--
-- The registry carries the definition; this model is its implementation (BL-001).

with episodes as (
    select * from {{ ref('clinical__episode') }}
),

person as (
    select * from {{ ref('clinical__person') }}
)

-- BL-005: clinical status is a disaggregation, so a cascade is a group-by rather than a
-- column per position: a registry's status list is its own, and no metric can enumerate it.
--
-- BL-006: retention is derived from the boundaries, not asserted here. The exited share is
-- sum(value_numeric) filter (where period_end is not null) / sum(value_numeric), at whatever
-- grain the consumer groups to.
--
-- D5 wide format: value_boolean is unused by this metric.
select
    'program_registry_enrolment'::text as metric_id,
    null::text as variant_id,
    e.episode_id::varchar as subject_id,
    -- BL-002: minute grain. period_end is NULL while the enrolment is open, which is the
    -- state most enrolments are in
    e.episode_start_datetime as period_start,
    e.episode_end_datetime as period_end,
    'minute'::text as period_granularity,
    -- BL-003: one enrolment per row, so the count contribution is always 1. Additive, so a
    -- data table summing it is correct at every grain
    1::numeric as value_numeric,
    null::boolean as value_boolean,

    -- BL-004: which registry the enrolment is in. Code, not name: the code is the stable
    -- identifier a data table and a report can be written against
    e.episode_source_value as registry_code,
    e.episode_source_name as registry_name,

    -- BL-005: cascade position, as the registry's own status code and name
    e.clinical_status_source_value as clinical_status_code,
    e.clinical_status_source_name as clinical_status,

    -- BL-006: whether the enrolment is still open, and what closed it. registration_status is
    -- the registration's own state; episode_end_source names the rule that resolved the
    -- boundary, so a consumer can tell a deactivation from a logged status change.
    --
    -- BL-014: the two are not interchangeable. An enrolment closed before the change log's
    -- coverage floor is inactive with no period_end (clinical__episode's BL-006), so exit
    -- status is read here and exit timing from period_end -- both carried through unchanged
    -- from the episode, which AC-014 pins, so this metric can never be the thing that lost a
    -- boundary
    e.registration_status,
    e.episode_end_source,

    -- BL-007: where the patient is currently being followed, and the type the registry
    -- configures. Emitted as the Tamanu id only: translating it to a consumer's own
    -- identifier -- a Tupaia entity code, a DHIS2 org unit -- is a consumer-layer concern
    e.currently_at_type,
    e.currently_at_id,

    -- BL-008: the facility that registered the patient, which is not necessarily where they
    -- are followed now. Named facility_id for the same reason as every other metric: it is
    -- the facility a consumer's entity crosswalk joins on
    e.care_site_id as facility_id,

    p.gender_source_value as sex,
    -- BL-009: age in whole years at enrolment.
    -- BL-013: unbanded -- an age classification is a presentation choice a deployment may set
    -- differently, so the consumer's data table bands it
    {{ age_years('e.episode_start_date', 'p') }} as age_years

from episodes e
-- BL-010: inner join. An episode's person is guaranteed by clinical__episode's own AC-010,
-- so this drops nothing; it is what makes sex and age safe to read
join person p on p.person_id = e.person_id
