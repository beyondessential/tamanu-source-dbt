-- Singular tests for clinical__visit_detail. One row per violation, tagged with the
-- acceptance criterion it breaks. See specs/dbt-model/clinical__visit_detail.md.

with encounters as (
    select * from {{ ref('encounters') }}
),

visit_detail as (
    select * from {{ ref('clinical__visit_detail') }}
),

-- AC-012: every encounter has at least one corresponding clinical__visit_detail row
-- (the grain is per-segment, so this checks existence, not a 1:1 row count). A missing
-- encounter means BL-003's inner join to map__omop_visit_type excluded every segment of
-- this encounter -- its encounter_type, or an encounter_history phase's encounter_type,
-- has no row in map__omop_visit_type (schema drift). This is the direct completeness
-- check; data_test__map__omop_visit_type_coverage flags the root cause (the unmapped
-- encounter_type value) earlier and independently of this test.
ac_012 as (
    select
        e.id as encounter_id,
        'AC-012' as failed_ac
    from encounters e
    where not exists (
            select 1 from visit_detail vd
            where vd.visit_occurrence_id = e.id
        )
)

select
    encounter_id,
    failed_ac
from ac_012
