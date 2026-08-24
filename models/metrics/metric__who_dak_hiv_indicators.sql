-- metric__who_dak_hiv_indicators -- D5 metric view for the WHO SMART guidelines HIV DAK
-- indicators registered in documentations/metrics/who_dak_hiv.yml.
-- Spec: specs/dbt-model/metric__who_dak_hiv_indicators.md (BL-001..BL-016).
--
-- Eleven of Web Annex C's 140 indicators: the ones whose numerator and denominator are
-- computable from the DAK's own data elements, as the generated forms collect them. Each
-- emits a count, and a rate is formed by the consumer from a numerator and its denominator --
-- so ART.3 viral suppression is who_dak_hiv_art_viral_suppression over
-- who_dak_hiv_art_routine_viral_load, at whatever grain the consumer groups to (BL-006).
--
-- Per-subject monthly rows: one row per qualifying subject per reporting month, value_numeric
-- 1 (BL-005). Annex C counts *clients*, so a client with two qualifying events in a month
-- contributes one row (BL-007) -- which is why the period is the month rather than the event
-- datetime, unlike the encounter-grained metrics.
--
-- Sources only from intermediate and clinical__ (D10). Nothing here bands age or resolves a
-- facility to a consumer's own code: both are the consumer layer's (BL-015, BL-016).

with answers as (
    select * from {{ ref('int__who_dak_hiv_form_answers') }}
),

-- BL-008: every ART and DSD numerator in Annex C is gated on "HIV status"='HIV-positive'.
-- The DAK carries that element on the HTS form (HIV.B.DE115), not on the care visit, so a
-- client seen only in care would fail a literal reading of the gate. A care-visit submission
-- is taken as equivalent evidence: the DAK's care and treatment process is for people living
-- with HIV, and excluding them would report zero on deployments that use the care form alone.
plhiv as (
    select distinct patient_id
    from answers
    where hiv_status = 'HIV-positive'
        or hiv_test_result = 'HIV-positive'
        or survey_code = 'carevisit'
),

-- BL-009: one row per indicator per qualifying event, before the per-client reduction. The
-- event date is the Annex C element that places the count in a reporting period, so each
-- indicator names its own.
events as (

    -- HTS.2 test volume (denominator). Annex C counts *tests* here, not clients, so the
    -- subject is the submission (BL-010)
    select
        'who_dak_hiv_hts_test' as metric_id,
        'test' as subject_grain,
        a.response_id as subject_id,
        a.hiv_test_result_returned_date as event_date,
        a.*
    from answers a
    where a.hiv_test_date is not null
        and a.hiv_test_result_returned_date is not null

    union all

    -- HTS.2 positive results returned (numerator). Either date places it in the period, so
    -- the earlier of the two anchors the count
    select
        'who_dak_hiv_hts_test_positive',
        'test',
        a.response_id,
        least(
            coalesce(a.hiv_test_result_returned_date, a.hiv_diagnosis_date),
            coalesce(a.hiv_diagnosis_date, a.hiv_test_result_returned_date)
        ),
        a.*
    from answers a
    where a.hiv_test_result = 'HIV-positive'
        and coalesce(a.hiv_test_result_returned_date, a.hiv_diagnosis_date) is not null

    union all

    -- HTS.3 clients tested (denominator)
    select
        'who_dak_hiv_hts_client_tested',
        'patient',
        a.patient_id,
        a.hiv_test_result_returned_date,
        a.*
    from answers a
    where a.hiv_test_date is not null
        and a.hiv_test_result_returned_date is not null

    union all

    -- HTS.3 clients testing positive (numerator)
    select
        'who_dak_hiv_hts_client_positive',
        'patient',
        a.patient_id,
        least(
            coalesce(a.hiv_test_result_returned_date, a.hiv_diagnosis_date),
            coalesce(a.hiv_diagnosis_date, a.hiv_test_result_returned_date)
        ),
        a.*
    from answers a
    where a.hiv_test_result = 'HIV-positive'
        and a.hiv_test_date is not null
        and coalesce(a.hiv_test_result_returned_date, a.hiv_diagnosis_date) is not null

    union all

    -- ART.4 new ART patients. The initiation date is the event, so a form recorded late still
    -- counts in the month treatment began (BL-011)
    select
        'who_dak_hiv_art_initiated',
        'patient',
        a.patient_id,
        a.art_start_date,
        a.*
    from answers a
    join plhiv on plhiv.patient_id = a.patient_id
    where a.on_art
        and a.art_start_date is not null

    union all

    -- ART.5 initiations with a baseline CD4 count (denominator)
    select
        'who_dak_hiv_art_cd4_at_initiation',
        'patient',
        a.patient_id,
        a.art_start_date,
        a.*
    from answers a
    join plhiv on plhiv.patient_id = a.patient_id
    where a.art_start_date is not null
        and a.baseline_cd4_test_date is not null
        and date_trunc('month', a.baseline_cd4_test_date) = date_trunc('month', a.art_start_date)
        and a.baseline_cd4_count is not null

    union all

    -- ART.5 late ART initiation (numerator): a baseline CD4 under 200 cells/mm3
    select
        'who_dak_hiv_art_late_initiation',
        'patient',
        a.patient_id,
        a.art_start_date,
        a.*
    from answers a
    join plhiv on plhiv.patient_id = a.patient_id
    where a.art_start_date is not null
        and a.baseline_cd4_test_date is not null
        and date_trunc('month', a.baseline_cd4_test_date) = date_trunc('month', a.art_start_date)
        and a.baseline_cd4_count < 200

    union all

    -- ART.3 routine viral load tests among those on ART six months or more (denominator).
    -- Annex C measures the six months against the reporting period end, which for a monthly
    -- period is the end of the sample's own month (BL-012)
    select
        'who_dak_hiv_art_routine_viral_load',
        'patient',
        a.patient_id,
        a.viral_load_sample_date,
        a.*
    from answers a
    join plhiv on plhiv.patient_id = a.patient_id
    where a.on_art
        and a.viral_load_sample_date is not null
        and a.viral_load_reason = 'Routine viral load test'
        and a.art_start_date
            < (date_trunc('month', a.viral_load_sample_date) + interval '1 month' - interval '6 months')::date

    union all

    -- ART.3 virological suppression (numerator): under 1000 copies/mL
    select
        'who_dak_hiv_art_viral_suppression',
        'patient',
        a.patient_id,
        a.viral_load_sample_date,
        a.*
    from answers a
    join plhiv on plhiv.patient_id = a.patient_id
    where a.on_art
        and a.viral_load_sample_date is not null
        and a.viral_load_reason = 'Routine viral load test'
        and a.viral_load_result < 1000
        and a.art_start_date
            < (date_trunc('month', a.viral_load_sample_date) + interval '1 month' - interval '6 months')::date

    union all

    -- DSD.3 clients assessed as eligible for a DSD ART model (denominator)
    select
        'who_dak_hiv_dsd_eligible',
        'patient',
        a.patient_id,
        a.dsd_eligibility_assessed_date,
        a.*
    from answers a
    join plhiv on plhiv.patient_id = a.patient_id
    where a.on_art
        and a.dsd_eligible
        and a.dsd_eligibility_assessed_date is not null

    union all

    -- DSD.3 clients enrolled in a DSD ART model (numerator). Annex C gives this numerator no
    -- date element, so the submission recording the enrolment places it (BL-013)
    select
        'who_dak_hiv_dsd_enrolled',
        'patient',
        a.patient_id,
        a.submitted_datetime::date,
        a.*
    from answers a
    join plhiv on plhiv.patient_id = a.patient_id
    where a.on_art
        and a.dsd_enrolled
),

-- BL-007: Annex C counts clients, so a client qualifying twice in a month counts once. The
-- earliest qualifying event in the month wins, and carries the facility and the age -- so a
-- client is attributed to where they were first counted rather than to an arbitrary visit.
reduced as (
    select distinct on (metric_id, subject_id, date_trunc('month', event_date))
        metric_id,
        subject_grain,
        subject_id,
        date_trunc('month', event_date)::date as period_start,
        (date_trunc('month', event_date) + interval '1 month' - interval '1 day')::date as period_end,
        event_date,
        patient_id,
        facility_id,
        sex,
        year_of_birth,
        month_of_birth,
        day_of_birth
    from events
    where event_date is not null
    order by metric_id, subject_id, date_trunc('month', event_date), event_date, response_id
)

select
    metric_id,
    -- BL-014: the standard definition, with no deployment variant
    null::text as variant_id,
    subject_id::varchar as subject_id,
    subject_grain,
    period_start,
    period_end,
    'month'::text as period_granularity,
    -- BL-005: one subject per row, so the count contribution is always 1
    1::numeric as value_numeric,
    null::boolean as value_boolean,

    facility_id,
    sex,
    -- BL-015: age in whole years at the qualifying event, unbanded. Annex C disaggregates by
    -- age; which bands is a reporting choice (GAM, MER and a national HMIS differ), so the
    -- consumer's data table bands it
    case
        when year_of_birth is not null then
            extract(year from age(
                event_date,
                make_date(year_of_birth, month_of_birth, day_of_birth)
            ))::int
    end as age_years

from reduced
