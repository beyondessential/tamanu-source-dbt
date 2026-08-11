-- metric__emergency_care -- D5 wide-format metric view for the emergency care
-- indicators registered in csv/metric_definitions.csv: ed_attendance,
-- ed_attendance_admitted (MAUI-6694).
-- Spec: specs/dbt-model/metric__emergency_care.md (BL-001..BL-007).
--
-- Supersedes ds__emergency_visit: same attendance definition (intake segment
-- carrying OMOP visit concept 9203), re-expressed as registered metrics so the
-- definitions are discoverable, externally anchored and reusable across
-- deployments rather than local to one dataset (BL-001).

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

-- BL-003: ED attendances are the first history segment of each encounter whose
-- OMOP visit concept is 9203/Emergency Room Visit -- covers emergency, triage
-- and observation. One row per attendance, attributed to that intake segment.
ed_attendances as (
    select
        vd.visit_occurrence_id,
        vd.visit_detail_start_date as presentation_date,
        loc.facility_id,
        pr.gender_source_value as sex,
        -- BL-005: visit-level concept 262 ('Emergency Room and Inpatient Visit')
        -- is the admitted episode-end status; it exists only at visit grain.
        vo.visit_concept_id = 262 as is_admitted,
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
    join locations loc
        on loc.id = vd.care_site_id
    -- BL-010: deliberately no facilities.is_sensitive filter -- these are pre-aggregated
    -- counts with no subject, so the metric covers standard and sensitive facilities alike.
    -- Do not add one -- excluding sensitive facilities would understate ED activity.
    where vd.preceding_visit_detail_id is null
        and vd.visit_detail_concept_id = 9203 -- OMOP 'Emergency Room Visit'
),

-- BL-004: band age once, and bucket to the reporting month, so the aggregates
-- below group on plain columns
ed_attendances_banded as (
    select
        date_trunc('month', presentation_date)::date as period_start,
        facility_id,
        sex,
        is_admitted,
        {{ age_group__who_primary_classification('age_years') }}
            as age_group__who_primary_classification
    from ed_attendances
    -- BL-002: exclude the incomplete current month; a partial final month reads
    -- as a collapse in a trend chart. current_date is the DB session date, as
    -- everywhere else in this repo -- see the spec for the sub-day lag this
    -- accepts at a month boundary.
    where date_trunc('month', presentation_date)
        < date_trunc('month', current_date)
),

-- one row per (month, facility, sex, age band) carrying both counts, so the
-- rate is computed from the same grouping rather than re-derived
attendances_by_month as (
    select
        period_start,
        facility_id,
        sex,
        age_group__who_primary_classification,
        count(*) as total_attendances,
        count(*) filter (where is_admitted) as total_admitted
    from ed_attendances_banded
    group by period_start, facility_id, sex, age_group__who_primary_classification
),

unioned as (
    select
        'ed_attendance' as metric_id,
        period_start,
        facility_id,
        sex,
        age_group__who_primary_classification,
        total_attendances::numeric as value
    from attendances_by_month

    union all

    select
        'ed_attendance_admitted' as metric_id,
        period_start,
        facility_id,
        sex,
        age_group__who_primary_classification,
        total_admitted::numeric as value
    from attendances_by_month
)

-- BL-006: no derived admission rate is emitted. Both the numerator
-- (ed_attendance_admitted) and the denominator (ed_attendance) are additive counts, so a
-- consumer forms the rate at whatever grain it groups to. A pre-computed proportion could
-- not be rolled up, and would sum incorrectly wherever a disaggregation was collapsed.

-- BL-007: D5 wide format. subject_id and value_boolean are unused -- these are
-- pre-aggregated counts, not per-subject or boolean facts.
{% set has_tupaia_mapping = var('integrations', {}).get('tupaia', {}).get('enabled', false) %}

select
    u.metric_id,
    null::text as variant_id,
    null::varchar as subject_id,
    u.period_start,
    (u.period_start + interval '1 month' - interval '1 day')::date as period_end,
    'month'::text as period_granularity,
    u.value as value_numeric,
    null::boolean as value_boolean,
    u.facility_id,
    -- BL-009: Tupaia facility id crosswalk, joined only when the deployment sets
    -- integrations.tupaia.enabled and supplies its own tupaia_facility_mapping seed, so this
    -- model still builds standalone here with no such seed present. Never NULL -- it is a data
    -- table filter column, and Tupaia's default array filter drops NULL rows, so an unmapped
    -- or unconfigured facility gets the literal 'Not available'.
    {% if has_tupaia_mapping -%}
    coalesce(tm.tupaia_facility_id, 'Not available') as tupaia_facility_id,
    {%- else -%}
        'Not available' as tupaia_facility_id,
    {%- endif %}
    u.sex,
    u.age_group__who_primary_classification
from unioned u
{%- if has_tupaia_mapping %}
left join {{ ref('tupaia_facility_mapping') }} tm
    on tm.tamanu_facility_id = u.facility_id
{%- endif %}
