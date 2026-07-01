-- Singular tests for clinical__visit_occurrence. One row per violation, tagged with the
-- acceptance criterion it breaks. See specs/dbt-model/clinical__visit_occurrence.md.

with visit as (
    select * from {{ ref('clinical__visit_occurrence') }}
),

-- AC-007: when visit_end_datetime is present it must not precede visit_start_datetime (BL-004)
ac_007 as (
    select
        visit_occurrence_id,
        'AC-007' as failed_ac
    from visit
    where visit_end_datetime is not null
        and visit_end_datetime < visit_start_datetime
)

select visit_occurrence_id, failed_ac from ac_007
