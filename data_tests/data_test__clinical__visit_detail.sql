-- Singular tests for clinical__visit_detail. One row per violation, tagged with the
-- acceptance criterion it breaks. See specs/dbt-model/clinical__visit_detail.md.

with visit_detail as (
    select * from {{ ref('clinical__visit_detail') }}
),

-- AC-006: when present, a segment's end must not precede its start (BL-002)
ac_006 as (
    select
        visit_detail_id,
        'AC-006' as failed_ac
    from visit_detail
    where visit_detail_end_datetime is not null
        and visit_detail_end_datetime < visit_detail_start_datetime
)

select visit_detail_id, failed_ac from ac_006
