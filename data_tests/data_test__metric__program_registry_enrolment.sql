-- Singular tests for metric__program_registry_enrolment. One row per violation, tagged with
-- the acceptance criterion it breaks.
-- See specs/dbt-model/metric__program_registry_enrolment.md, AC-014.

with metric as (
    select * from {{ ref('metric__program_registry_enrolment') }}
),

episode as (
    select * from {{ ref('clinical__episode') }}
),

-- AC-014: the boundary columns are carried through from clinical__episode unchanged, so an
-- inactive row with a NULL period_end is BL-006's pre-coverage tail -- the closing change
-- predates the change log's coverage floor and nothing records when it happened -- and never a
-- boundary this metric dropped or overwrote (BL-006, BL-014).
--
-- Compared with `is distinct from` so a NULL on either side is judged rather than skipped by
-- three-valued logic. The join is inner because AC-001 and clinical__episode's AC-001 make it
-- one-to-one; a row that has no episode at all is caught by the row-count arm below
ac_014_boundaries as (
    select
        m.subject_id,
        'AC-014' as failed_ac
    from metric m
    join episode e on e.episode_id = m.subject_id
    where m.registration_status is distinct from e.registration_status
        or m.period_end is distinct from e.episode_end_datetime
        or m.episode_end_source is distinct from e.episode_end_source
),

-- AC-014: and every episode reaches the metric, so the tail cannot be quietly filtered out
-- instead of carried
ac_014_population as (
    select
        'row count' as subject_id,
        'AC-014' as failed_ac
    from (
        select
            (select count(*) from metric) as metric_rows,
            (select count(*) from episode) as episode_rows
    ) counts
    where metric_rows != episode_rows
)

select
    subject_id,
    failed_ac
from ac_014_boundaries
union all
select
    subject_id,
    failed_ac
from ac_014_population
