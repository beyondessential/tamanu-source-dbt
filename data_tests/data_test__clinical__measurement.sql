-- clinical__measurement invariants that a schema test cannot express. One row per violation,
-- tagged by failed_ac.
--
-- AC-008 (BL-011): no lab measurement comes from a withdrawn lab request.
-- AC-009 (BL-009): every lab measurement carries a non-blank reading -- a typed result or the
-- result its test type encodes.

with measurements as (
    select * from {{ ref('clinical__measurement') }}
),

lab_tests as (
    select * from {{ ref('lab_tests') }}
),

lab_requests as (
    select * from {{ ref('lab_requests') }}
),

withdrawn_tests as (
    select lt.id
    from lab_tests lt
    join lab_requests lr on lr.id = lt.lab_request_id
    where lr.status in (
        'cancelled', 'deleted', 'entered-in-error', 'invalidated', 'rejected', 'sample-not-collected'
    )
)

select
    m.measurement_id,
    'ac_008_clinical__measurement_no_withdrawn_lab_request' as failed_ac
from measurements m
join withdrawn_tests w on w.id = m.measurement_id
where m.measurement_type_source_value = 'lab'

union all

select
    m.measurement_id,
    'ac_009_clinical__measurement_lab_reading_not_blank' as failed_ac
from measurements m
where m.measurement_type_source_value = 'lab'
    and coalesce(trim(m.value_source_value), '') = ''
