-- Singular tests for clinical__visit_detail. One row per violation, tagged with the
-- acceptance criterion it breaks. See specs/dbt-model/clinical__visit_detail.md.

with visit_detail as (
    select * from {{ ref('clinical__visit_detail') }}
),

visit_occurrence as (
    select * from {{ ref('clinical__visit_occurrence') }}
),

-- earliest segment start per visit
first_segment as (
    select
        visit_occurrence_id,
        min(visit_detail_start_datetime) as first_segment_start
    from visit_detail
    group by visit_occurrence_id
),

-- AC-011: the earliest segment of every visit must cover the visit start, so the opening
-- phase before the first encounter_history change is never left uncovered. Segments begin
-- at each encounter_history.datetime, so this holds only if Tamanu records an initial
-- history row at encounter creation; the test makes that assumption explicit and fails
-- loudly if it ever stops holding (BL-002, BL-005)
ac_011 as (
    select
        fs.visit_occurrence_id,
        'AC-011' as failed_ac
    from first_segment fs
    join visit_occurrence vo on vo.visit_occurrence_id = fs.visit_occurrence_id
    where fs.first_segment_start > vo.visit_start_datetime
)

select visit_occurrence_id, failed_ac from ac_011
