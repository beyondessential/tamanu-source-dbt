-- Singular tests for clinical__visit_occurrence. One row per violation, tagged with the
-- acceptance criterion it breaks. See specs/dbt-model/clinical__visit_occurrence.md.

with encounters as (
    select * from {{ ref('encounters') }}
),

visit_occurrence as (
    select * from {{ ref('clinical__visit_occurrence') }}
),

-- AC-011: every encounter has a corresponding clinical__visit_occurrence row. A missing
-- row means BL-002's inner join to map__omop_visit_type excluded this encounter -- its
-- encounter_type has no row in map__omop_visit_type (schema drift). This is the direct
-- completeness check; data_test__map__omop_visit_type_coverage flags the root cause (the
-- unmapped encounter_type value) earlier and independently of this test.
ac_011 as (
    select
        e.id as encounter_id,
        'AC-011' as failed_ac
    from encounters e
    left join visit_occurrence vo
        on vo.visit_occurrence_id = e.id
    where vo.visit_occurrence_id is null
)

select encounter_id, failed_ac from ac_011
