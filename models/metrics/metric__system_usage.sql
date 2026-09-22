-- metric__system_usage -- D5 wide-format metric view for two generic Tamanu
-- platform-usage indicators (MAUI-6780). Period (per-month) counts.
-- Spec: specs/dbt-model/metric__system_usage.md (BL-001..008).
--
--   clinical_events        (variant_id NULL)                   -- BL-002  OMOP-lite canonical
--   clinical_events        (variant_id clinical_events_legacy) -- BL-002c legacy-parity bridge
--   active_users           (variant_id NULL)                   -- BL-003  active authors
--
-- Shared across every deployment (built from generic bases/ + clinical/); no
-- per-deployment SQL. Consumers roll facility up to country and use `sex` for
-- the GEDSI cut. Zero-value slices are not emitted (BL-005).

-- Materialisation and schema are inherited from the `metrics` block in
-- dbt_project.yml (table on the analytics replica, view everywhere else, built
-- into public_tupaia on analytics) -- the same convention every other metric__
-- model follows. This model is a ~20-way UNION ALL over full base scans with
-- enc joined many times, so the replica-side table matters here: it avoids
-- re-executing the lot on every Tupaia Data Table query.

with

-- =====================================================================
-- CANONICAL clinical_events (BL-002) + active_users (BL-003)
-- One row per OMOP-lite clinical-event record across the four event
-- domains. event_datetime is the domain event time (local naive), never
-- created_at (BL-002a).
-- =====================================================================
omop_events as (
    select person_id, provider_id, visit_occurrence_id,
        condition_start_datetime as event_datetime
    from {{ ref('clinical__condition_occurrence') }}

    union all

    select person_id, provider_id, visit_occurrence_id,
        drug_exposure_start_datetime as event_datetime
    from {{ ref('clinical__drug_exposure') }}

    union all

    select person_id, provider_id, visit_occurrence_id,
        measurement_datetime as event_datetime
    from {{ ref('clinical__measurement') }}

    union all

    select person_id, provider_id, visit_occurrence_id,
        observation_datetime as event_datetime
    from {{ ref('clinical__observation') }}
),

-- BL-006: facility via the event's visit -> care site (department) -> facility.
-- (clinical__visit_occurrence.care_site_id is the encounter's department_id.)
-- BL-004: system/test USER exclusion is NOT yet implemented here -- see OQ-003.
-- (Test patients are already excluded upstream via bases/encounters/patients.)
visit_facility as (
    select
        vo.visit_occurrence_id,
        cs.facility_id
    from {{ ref('clinical__visit_occurrence') }} vo
    left join {{ ref('ref__care_site') }} cs
        on cs.care_site_id = vo.care_site_id
),

omop_enriched as (
    select
        date_trunc('month', e.event_datetime)::date as period_start,
        vf.facility_id,
        per.gender_source_value as sex,
        e.provider_id
    from omop_events e
    left join visit_facility vf
        on vf.visit_occurrence_id = e.visit_occurrence_id
    left join {{ ref('clinical__person') }} per
        on per.person_id = e.person_id
    where e.event_datetime is not null  -- BL-002a
),

clinical_events_canonical as (
    select
        'clinical_events'::text as metric_id,
        null::text as variant_id,
        period_start,
        facility_id,
        sex,
        count(*)::numeric as value_numeric
    from omop_enriched
    group by period_start, facility_id, sex
),

-- BL-003 / BL-006: active_users is emitted at NATIONAL grain only -- one row
-- per month with facility_id = NULL meaning "all facilities in the deployment".
-- A distinct-user count is non-additive across facilities (a user active at two
-- facilities would be double-counted by a facility-level roll-up), and the
-- consumer's actual ask (bes__phr_mel_1_1.total_users, MAUI-6780) is the national
-- number. So we compute count(distinct provider_id) over the whole deployment and
-- do NOT split by facility. NULL provider contributes nobody.
--
-- BL-003: only provider_ids that resolve to a real Tamanu user are counted.
-- clinical__drug_exposure and clinical__observation set
-- provider_id = coalesce(recorded_by_id, given_by), and given_by is free text
-- that may not reference a user at all -- which is why both of those models
-- scope their provider FK test off these rows. Counting provider_id raw would
-- invent phantom "users" from hand-typed names, and would count one clinician
-- twice when they appear both as a UUID and as a typed name. The semi-join
-- against ref__provider (provider_id unique, AC-002) cannot fan out, and it
-- subsumes the NULL check since NULL never matches IN.
active_users_metric as (
    select
        'active_users'::text as metric_id,
        null::text as variant_id,
        period_start,
        null::text as facility_id,
        null::text as sex,
        count(distinct provider_id)::numeric as value_numeric
    from omop_enriched
    where provider_id in (select provider_id from {{ ref('ref__provider') }})
    group by period_start
),

-- =====================================================================
-- LEGACY-PARITY variant clinical_events (BL-002c)
-- Reproduces data-staging ds__clinical_events 1:1 from bases/, at the
-- legacy grain (request/response level), so the series is continuous
-- across the data-staging sunset (D7). NOT sourced from OMOP-lite.
-- NUMERIC PARITY WITH ds__clinical_events MUST BE VALIDATED ON A REAL DB
-- before this variant is relied on for reporting -- see OQ-005 in the spec.
-- =====================================================================

-- Encounter -> patient + facility, the shared attribution for every
-- encounter-scoped legacy event.
enc as (
    select
        e.id as encounter_id,
        e.patient_id,
        l.facility_id
    from {{ ref('encounters') }} e
    left join {{ ref('locations') }} l
        on l.id = e.location_id
),

legacy_events as (
    -- Notes recorded (encounter notes)
    select enc.patient_id, n.datetime::timestamp as event_datetime, enc.facility_id
    from {{ ref('notes') }} n
    join enc on enc.encounter_id = n.record_id
    where n.record_type = 'Encounter'

    union all

    -- Procedures recorded
    select enc.patient_id, pr.date::timestamp, enc.facility_id
    from {{ ref('procedures') }} pr
    join enc on enc.encounter_id = pr.encounter_id

    union all

    -- Lab requests received
    select enc.patient_id, lr.requested_datetime::timestamp, enc.facility_id
    from {{ ref('lab_requests') }} lr
    join enc on enc.encounter_id = lr.encounter_id

    union all

    -- Lab requests resulted (published)
    select enc.patient_id, lr.published_datetime::timestamp, enc.facility_id
    from {{ ref('lab_requests') }} lr
    join enc on enc.encounter_id = lr.encounter_id
    where lr.status = 'published'

    union all

    -- Imaging requests received
    select enc.patient_id, ir.datetime::timestamp, enc.facility_id
    from {{ ref('imaging_requests') }} ir
    join enc on enc.encounter_id = ir.encounter_id

    union all

    -- Imaging requests resulted
    select enc.patient_id, irr.datetime::timestamp, enc.facility_id
    from {{ ref('imaging_results') }} irr
    join {{ ref('imaging_requests') }} ir on ir.id = irr.imaging_request_id
    join enc on enc.encounter_id = ir.encounter_id

    union all

    -- Medication documented (prescriptions linked to an encounter)
    select enc.patient_id, p.datetime::timestamp, enc.facility_id
    from {{ ref('encounter_prescriptions') }} ep
    join {{ ref('prescriptions') }} p on p.id = ep.prescription_id
    join enc on enc.encounter_id = ep.encounter_id

    union all

    -- Vaccination recorded -- legacy Given/Not given/Unknown. Explicit allow-list
    -- so SCHEDULED / MISSED / RECORDED_IN_ERROR are excluded (a recorded-in-error
    -- vaccination is not a clinical event). Exact enum<->legacy mapping: OQ-005.
    select enc.patient_id, va.datetime::timestamp, coalesce(l.facility_id, enc.facility_id)
    from {{ ref('vaccine_administrations') }} va
    left join enc on enc.encounter_id = va.encounter_id
    left join {{ ref('locations') }} l on l.id = va.location_id
    where va.status in ('GIVEN', 'NOT_GIVEN', 'UNKNOWN')

    union all

    -- Birth registration
    select pbd.patient_id, pbd.registration_date::timestamp, pbd.birth_facility_id
    from {{ ref('patient_birth_data') }} pbd

    union all

    -- Form completed (programs / obsolete surveys)
    select enc.patient_id,
        coalesce(sr.end_datetime, sr.start_datetime)::timestamp, enc.facility_id
    from {{ ref('survey_responses') }} sr
    join {{ ref('surveys') }} s on s.id = sr.survey_id
    join enc on enc.encounter_id = sr.encounter_id
    where s.survey_type in ('programs', 'obsolete')

    union all

    -- Referrals submitted
    select enc.patient_id,
        coalesce(sr.end_datetime, sr.start_datetime)::timestamp, enc.facility_id
    from {{ ref('survey_responses') }} sr
    join {{ ref('surveys') }} s on s.id = sr.survey_id
    join enc on enc.encounter_id = sr.encounter_id
    where s.survey_type = 'referral'

    union all

    -- Vitals recorded
    select enc.patient_id,
        coalesce(sr.end_datetime, sr.start_datetime)::timestamp, enc.facility_id
    from {{ ref('survey_responses') }} sr
    join {{ ref('surveys') }} s on s.id = sr.survey_id
    join enc on enc.encounter_id = sr.encounter_id
    where s.survey_type = 'vitals'

    union all

    -- Deaths record (dated by the patient's date of death)
    select pdd.patient_id, pat_d.date_of_death::timestamp, pdd.facility_id
    from {{ ref('patient_death_data') }} pdd
    join {{ ref('patients') }} pat_d on pat_d.id = pdd.patient_id

    union all

    -- Diagnoses recorded (base encounter_diagnoses already excludes
    -- disproven/error certainties -- see OQ-005 for exact ds__clinical_events parity)
    select enc.patient_id, ed.datetime::timestamp, enc.facility_id
    from {{ ref('encounter_diagnoses') }} ed
    join enc on enc.encounter_id = ed.encounter_id

    union all

    -- Patient letter creation
    select enc.patient_id, dm.created_datetime::timestamp, enc.facility_id
    from {{ ref('document_metadata') }} dm
    join enc on enc.encounter_id = dm.encounter_id

    union all

    -- Patients added to program registry
    select ppr.patient_id, ppr.datetime::timestamp, ppr.registering_facility_id
    from {{ ref('patient_program_registrations') }} ppr

    union all

    -- Status changed on program registry (clinical status differs from prior log).
    -- prev_clinical_status_id is not null excludes the first log of each
    -- registration (that is the "added to registry" event, counted above; without
    -- the guard every registration would be double-counted as a status change).
    select cl.patient_id, cl.datetime::timestamp, cl.facility_id
    from (
        select
            patient_id,
            datetime,
            facility_id,
            clinical_status_id,
            lag(clinical_status_id) over (
                partition by id order by datetime, logged_at
            ) as prev_clinical_status_id
        from {{ ref('patient_program_registrations_change_logs') }}
    ) cl
    where cl.prev_clinical_status_id is not null
        and cl.clinical_status_id is distinct from cl.prev_clinical_status_id
),

legacy_enriched as (
    select
        date_trunc('month', le.event_datetime)::date as period_start,
        le.facility_id,
        pat.sex,
        le.patient_id
    from legacy_events le
    left join {{ ref('patients') }} pat on pat.id = le.patient_id
    where le.event_datetime is not null
),

-- Legacy parity is its own registered metric_id (variant_of = clinical_events in
-- the registry), NOT a variant_id under clinical_events -- so a consumer that
-- selects metric_id = 'clinical_events' gets only the canonical series and never
-- double-counts. variant_id stays NULL (reserved for future same-metric variants).
clinical_events_legacy as (
    select
        'clinical_events_legacy'::text as metric_id,
        null::text as variant_id,
        period_start,
        facility_id,
        sex,
        count(*)::numeric as value_numeric
    from legacy_enriched
    group by period_start, facility_id, sex
),

unioned as (
    select * from clinical_events_canonical
    union all
    select * from active_users_metric
    union all
    select * from clinical_events_legacy
)

-- BL-005: month bounds + granularity. The `value_numeric > 0` filter is a
-- defensive guard on the no-data contract (absent slice = no-data, never a 0
-- row). Counts here are always >= 1 by construction, so it is effectively a
-- no-op today, but it keeps the contract explicit if the aggregation changes.
select
    metric_id,
    variant_id,
    null::uuid as subject_id,
    period_start,
    (period_start + interval '1 month' - interval '1 day')::date as period_end,
    'month'::text as period_granularity,
    value_numeric,
    null::boolean as value_boolean,
    facility_id,
    sex
from unioned
where value_numeric > 0
