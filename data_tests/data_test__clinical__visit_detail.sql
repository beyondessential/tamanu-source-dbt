-- Singular tests for clinical__visit_detail. One row per violation, tagged with the
-- acceptance criterion it breaks. See specs/dbt-model/clinical__visit_detail.md.

with encounters as (
    select * from {{ ref('encounters') }}
),

visit_detail as (
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
),

-- AC-013: every encounter has at least one corresponding clinical__visit_detail row
-- (the grain is per-segment, so this checks existence, not a 1:1 row count). A missing
-- encounter means BL-003's inner join to map__omop_visit_type excluded every segment of
-- this encounter -- its encounter_type, or an encounter_history phase's encounter_type,
-- has no row in map__omop_visit_type (schema drift). This is the direct completeness
-- check; data_test__map__omop_visit_type_coverage (AC-012) flags the root cause (the
-- unmapped encounter_type value) earlier and independently of this test.
ac_013 as (
    select
        e.id as visit_occurrence_id,
        'AC-013' as failed_ac
    from encounters e
    where not exists (
            select 1 from visit_detail vd
            where vd.visit_occurrence_id = e.id
        )
)

select visit_occurrence_id, failed_ac from ac_011
union all
select visit_occurrence_id, failed_ac from ac_013
