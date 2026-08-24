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

-- BL-012: "more than six months before the reporting period end date", where the reporting
-- period is the month the sample falls in -- so the cutoff is that month's last day less six
-- months, not its first. Written once because ART.3's numerator and denominator share it, and a
-- rule duplicated across two selects is a rule that drifts.
{% set art_established_six_months %}
    a.art_start_date < (
        date_trunc('month', a.viral_load_sample_date)
        + interval '1 month' - interval '1 day' - interval '6 months'
    )::date
{% endset %}

with answers as (
    select * from {{ ref('int__who_dak_hiv_form_answers') }}
),

-- BL-018: the client's last known state at each month end, for the indicators Annex C defines
-- at a point in time rather than on an event
client_months as (
    select * from {{ ref('int__who_dak_hiv_client_month_state') }}
),

-- BL-022: one row per client per key population they belong to. A MultiSelect answer, so a
-- client can be in several -- which is why the key-population indicators are their own metrics
-- rather than a column on the counts above: a client who is both a sex worker and a person who
-- injects drugs belongs in both of Annex C's disaggregation groups, and adding a column would
-- make the plain count double them.
key_populations as (
    select * from {{ ref('int__who_dak_hiv_key_populations') }}
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
        least(a.hiv_test_result_returned_date, a.hiv_diagnosis_date),
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
        least(a.hiv_test_result_returned_date, a.hiv_diagnosis_date),
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
        and {{ art_established_six_months }}

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
        and {{ art_established_six_months }}

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

    union all

    -- ART.9 treatment-limiting ARV toxicity (numerator): treatment stopped for toxicity, or a
    -- regimen substitution for toxicity on any line. Annex C sums the two, so a client with
    -- both in one month is still one client -- the reduction below sees to that (BL-023)
    select
        'who_dak_hiv_art_toxicity',
        'patient',
        a.patient_id,
        a.art_stopped_date,
        a.*
    from answers a
    join plhiv on plhiv.patient_id = a.patient_id
    where a.art_stopped_reason like '%Toxicity%'
        and a.art_stopped_date is not null

    -- one branch per regimen line, because Annex C counts a substitution on *any* line whose
    -- date falls in the reporting period. Collapsing the three dates into one -- which line it
    -- was is not part of the indicator -- keeps only one of them, so a client substituted on
    -- first line in January and on third line in June would go uncounted in June (BL-023).
    -- More than one in the same month is reduced to a single row below.
    {%- for line in ['first', 'second', 'third'] %}

    union all

    select
        'who_dak_hiv_art_toxicity',
        'patient',
        a.patient_id,
        a.substitution_{{ line }}_line_date,
        a.*
    from answers a
    join plhiv on plhiv.patient_id = a.patient_id
    where a.on_art
        and a.regimen_substitution_reason like '%Toxicity%'
        and a.substitution_{{ line }}_line_date is not null
    {%- endfor %}
),

-- BL-018: the point-in-time indicators. These are counted from the carried-forward state at a
-- month end, not from an event in the month, so they live in their own union: a client on ART
-- who was not seen at all in a month is still on ART.
month_end_events as (

    -- ART.1 people living with HIV on ART at the reporting period end date. Annex C's
    -- denominators are population estimates from outside Tamanu, so only the count is emitted
    -- (BL-024). It doubles as ART.9's denominator, which Annex C words as clients on ART within
    -- the reporting period.
    select
        'who_dak_hiv_art_on_art' as metric_id,
        'patient' as subject_grain,
        cm.patient_id as subject_id,
        cm.month_start,
        cm.month_end,
        cm.patient_id,
        cm.facility_id,
        cm.sex,
        cm.age_years,
        null::int as months_on_dsd,
        null::text as key_population
    from client_months cm
    join plhiv on plhiv.patient_id = cm.patient_id
    where cm.on_art

    union all

    -- DSD.4 clients whose DSD ART model started before the month end (denominator). Annex C
    -- reports this at 12, 24, 36, 48 and 60 months; months_on_dsd is emitted so a consumer
    -- bands it rather than the model carrying five near-identical metrics (BL-025)
    select
        'who_dak_hiv_dsd_retention_eligible',
        'patient',
        cm.patient_id,
        cm.month_start,
        cm.month_end,
        cm.patient_id,
        cm.facility_id,
        cm.sex,
        cm.age_years,
        cm.months_on_dsd,
        null::text
    from client_months cm
    join plhiv on plhiv.patient_id = cm.patient_id
    where cm.on_art
        and cm.months_on_dsd >= 12

    union all

    -- DSD.4 clients still enrolled in the model (numerator)
    select
        'who_dak_hiv_dsd_retained',
        'patient',
        cm.patient_id,
        cm.month_start,
        cm.month_end,
        cm.patient_id,
        cm.facility_id,
        cm.sex,
        cm.age_years,
        cm.months_on_dsd,
        null::text
    from client_months cm
    join plhiv on plhiv.patient_id = cm.patient_id
    where cm.on_art
        and cm.months_on_dsd >= 12
        and cm.dsd_enrolled

    union all

    -- HTS.3 and ART.1 disaggregated by key population, which Annex C asks for on both. One row
    -- per client per population, so the count is of client-population pairs: summing across
    -- populations double-counts a client in two of them, which is what Annex C's own
    -- disaggregation does (BL-022)
    select
        'who_dak_hiv_art_on_art_key_population',
        'patient',
        cm.patient_id || ';' || kp.key_population,
        cm.month_start,
        cm.month_end,
        cm.patient_id,
        cm.facility_id,
        cm.sex,
        cm.age_years,
        null::int,
        kp.key_population
    from client_months cm
    join plhiv on plhiv.patient_id = cm.patient_id
    join key_populations kp on kp.patient_id = cm.patient_id
    where cm.on_art
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
        patient_id,
        facility_id,
        sex,
        case
            when year_of_birth is not null then
                extract(year from age(
                    event_date,
                    make_date(year_of_birth, month_of_birth, day_of_birth)
                ))::int
        end as age_years
    from events
    where event_date is not null
    order by metric_id, subject_id, date_trunc('month', event_date), event_date, response_id
),

-- the two unions meet here: an event-anchored row and a month-end row are the same shape, and
-- either way it is one subject counted once in one month
all_rows as (
    select
        metric_id,
        subject_grain,
        subject_id,
        period_start,
        period_end,
        facility_id,
        sex,
        age_years,
        null::int as months_on_dsd,
        null::text as key_population
    from reduced

    union all

    select
        metric_id,
        subject_grain,
        subject_id,
        month_start,
        month_end,
        facility_id,
        sex,
        age_years,
        months_on_dsd,
        key_population
    from month_end_events
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
    -- BL-015: age in whole years, unbanded -- at the qualifying event for an event-anchored
    -- indicator, at the month end for a point-in-time one. Annex C disaggregates by age; which
    -- bands is a reporting choice (GAM, MER and a national HMIS differ), so the consumer's data
    -- table bands it
    age_years,

    -- BL-025: whole months since the client's DSD model started, so a consumer selects Annex
    -- C's 12/24/36/48/60-month cohort. NULL on every indicator that is not DSD.4
    months_on_dsd,
    -- BL-022: the key population this row counts the client in. NULL except on the
    -- key-population metric, whose rows are client-population pairs
    key_population

from all_rows
